import 'package:web/web.dart' as web;

/// A small heading placed before [element]. Returns it.
web.HTMLHeadingElement addHeading(web.Element element, String title) {
  final heading = web.document.createElement('h2') as web.HTMLHeadingElement
    ..className = 'small'
    ..textContent = title;
  element.before(heading);
  return heading;
}

/// A small heading and a line of explanation placed before [element].
/// Returns the line, for explanations that change.
web.HTMLParagraphElement addExplainedHeading(web.Element element, String title, [String explanation = '']) {
  addHeading(element, title);
  final line = web.document.createElement('p') as web.HTMLParagraphElement
    ..className = 'meta'
    ..textContent = explanation;
  element.before(line);
  return line;
}
