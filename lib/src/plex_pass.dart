// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Telling a refusal for want of a Plex Pass or Remote Watch Pass from
/// any other: PMS has no code for it, only wording. Not exported.
library;

import 'plex_error_type.dart';
import 'plex_exception.dart';

/// [e] as a [PlexErrorType.passRequired] error when it is a 4xx whose
/// text says so; [e] itself otherwise. A `401`, a `404` and a `498` are
/// never one, and neither is an HTML page.
PlexException classifyPassRequired(PlexException e) {
  final status = e.statusCode;
  if (status == null ||
      status < 400 ||
      status >= 500 ||
      status == 401 ||
      status == 404 ||
      status == 498) {
    return e;
  }
  final text = e.body ?? e.message;
  if (_looksLikeHtml(text) || !mentionsPass(text)) return e;
  return e.withType(PlexErrorType.passRequired);
}

bool _looksLikeHtml(String text) {
  final head = text.trimLeft().toLowerCase();
  return head.startsWith('<!doctype html') || head.startsWith('<html');
}

/// Whether [text] says playback needs a Plex Pass or Remote Watch Pass.
bool mentionsPass(String text) => _passPattern.hasMatch(text);

final RegExp _passPattern = RegExp(
  r'plex\s*pass|remote\s*watch|remote\s+(?:play(?:back)?|stream(?:ing)?|'
  r'access)[^.]{0,60}(?:requir|subscri|not\s+(?:allowed|available|'
  r'permitted))|subscription\s+(?:is\s+)?required',
  caseSensitive: false,
);
