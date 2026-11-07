// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Reads the committed PMS answers in `test/fixtures/real/`.
library;

import 'dart:convert';
import 'dart:io';

/// The decoded `test/fixtures/real/[name].json`.
Map<String, Object?> realFixture(String name) =>
    jsonDecode(File('test/fixtures/real/$name.json').readAsStringSync())
        as Map<String, Object?>;
