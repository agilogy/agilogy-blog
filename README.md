# Agilogy blog

Finally, an Agilogy blog that will hopefully work.

- Proudly written in Markdown
- Rendered by Jekyll
- Styled by an adapted Hitchens theme
- (Closed) Source: https://github.com/agilogy/agilogy-blog

## Search engine indexing

- [Google](https://search.google.com/search-console?action=inspect&utm_medium=referral&utm_campaign=9012289&resource_id=http://blog.agilogy.com/)
- [Bing](https://www.bing.com/webmasters/home?siteUrl=http://blog.agilogy.com/) (also used by Duck Duck Go)

## In progress Backlog

- Enhance parsers errors. e.g. When extending arrays further than just boolean arrays it only tells me that `]` is expected, but a boolean would be also valid.

- Error when a branch has consumed chars:

  ```bash
  Expected :Right(JsonObject(Map("a" -> JsonNumber("23"), "b" -> JsonArray(List(JsonObject(Map("c" -> JsonNull)))))))
  Actual   :Left(ParseError("{"a":23,"b":[{"c":null}]}", 7, List(""true"", ""false"", "string", "number", ""["", ""}"")))
  ```

  