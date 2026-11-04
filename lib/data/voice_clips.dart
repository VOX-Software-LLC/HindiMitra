/// Male and female recordings from the hindi-letters-app project, bundled in
/// assets/audio/male/ and assets/audio/female/ (same files in both).
///
/// letter_<id>.wav — the letter on its own, for every vowel and consonant.
/// example_<id>.wav — "क से …" with the example word, only for letters whose
/// example word is the same as in letters.json (the others keep word_<id>.mp3).
const voiceGenders = ['female', 'male'];

const voiceExampleLetterIds = <String>{
  'v01', 'v02', 'v03', 'v04', 'v05', 'v06', 'v07', 'v08', 'v09', 'v10', 'v11', 'v12', 'v13',
  'c02', 'c03', 'c06', 'c09', 'c11', 'c13', 'c15', 'c18', 'c19', 'c20', 'c21', 'c22', 'c24',
  'c25', 'c26', 'c27', 'c29', 'c33', 'c34', 'c35', 'c36',
};

/// The letters.json id ('v01', 'c14', …) for a bundled letter clip id, or null.
String? voiceLetterId(String clipId) =>
    RegExp(r'^letter_([vc]\d\d)$').firstMatch(clipId)?.group(1);
