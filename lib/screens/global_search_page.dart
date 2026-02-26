import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/core/utils/date_formatter.dart';
import 'package:messaging/cubit/global_search_cubit.dart';
import 'package:messaging/screens/single_chat_screen.dart';
import 'package:messaging/screens/widgets/contact_name_text.dart';
import 'package:messaging/services/contact_service.dart';

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocProvider(
      create: (context) => GlobalSearchCubit(),
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: TextField(
              controller: _controller,
              autofocus: true, // Keyboard pops up immediately
              decoration: const InputDecoration(
                filled: false,
                hintText: "Search messages",
                border: InputBorder.none,
              ),
              onChanged: (value) =>
                  context.read<GlobalSearchCubit>().search(value),
            ),
          ),
          body: BlocBuilder<GlobalSearchCubit, GlobalSearchState>(
            builder: (context, state) {
              if (state is GlobalSearchLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is GlobalSearchLoaded) {
                return ListView.separated(
                  separatorBuilder: (context, index) => Divider(
                    color: theme.colorScheme.surfaceContainer,
                    thickness: 0.8,
                  ),
                  itemCount: state.results.length,
                  itemBuilder: (context, index) {
                    final message = state.results[index];
                    if (state.results.isEmpty) {
                      return Center(
                          child: Text("Nothing found for '${state.query}'"));
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      leading: Icon(
                        Icons.message_outlined,
                        color: theme.primaryColor,
                      ),
                      title: ContactNameText(
                          unread: false,
                          rawAddress: message.address,
                          contactStream: ContactService().contactStream),
                      // The sender
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SearchHighlightText(
                              text: message.body,
                              query: state.query,
                              style: const TextStyle(color: Colors.grey)),
                              Text(formatDate(message.date),style: theme.textTheme.labelSmall!.copyWith(color: theme.colorScheme.tertiary),)
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SingleChatScreen(
                                threadId: message.threadId,
                                address: message.address,
                                searchedMessage: message,
                              ),
                            ));
                      },
                    );
                  },
                );
              }
              return Center(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    color: theme.colorScheme.surfaceContainerHighest,
                    size: 30,
                  ),
                  Text(
                    "Start typing to search...",
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ],
              ));
            },
          ),
        );
      }),
    );
  }
}

class SearchHighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;

  const SearchHighlightText(
      {required this.text, required this.query, required this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return Text(text, style: style);
    }

    final matches = query.toLowerCase();
    final List<TextSpan> spans = [];
    int start = 0;
    int indexOfMatch;

    while ((indexOfMatch = text.toLowerCase().indexOf(matches, start)) != -1) {
      // Add normal text before match
      spans.add(TextSpan(text: text.substring(start, indexOfMatch)));
      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(indexOfMatch, indexOfMatch + matches.length),
        style: style.copyWith(
            color: theme.primaryColor, fontWeight: FontWeight.bold),
      ));
      start = indexOfMatch + matches.length;
    }
    spans.add(TextSpan(text: text.substring(start)));

    return RichText(text: TextSpan(style: style, children: spans));
  }
}
