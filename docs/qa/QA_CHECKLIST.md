# Hindi content & audio QA checklist

Two layers of QA:

1. **Automated** — `flutter test test/content_qa_test.dart` checks every letter, word,
   translation entry and audio clip and writes [content_qa_report.md](content_qa_report.md).
   It fails the build on any FAIL, so it doubles as a regression test.
2. **Listening (human)** — a person who speaks Hindi plays each clip and ticks the
   last columns below. A machine cannot judge whether a recording *sounds* right.

## What the automated audit checks

| Area | Checks |
|---|---|
| Audio catalog | every clip listed once; one clip per text; every listed id has a file; every file is listed |
| Audio files | valid MP3 frames; duration within range (0.25–4 s, phrases 0.6–8 s); no byte-identical recording used for two different texts (a matra may share its vowel's recording) |
| Letters | letter clip text = the letter; example-word clip exists; example word contains the letter; stroke template exists and stroke count matches; romanization and pronunciation present |
| Matras | clip exists; romanization matches its vowel |
| Spelling | every Devanagari word in all lesson data: no matra/virama/nukta at the start, no matra without a consonant, no two matras in a row, no virama at the end, no nasal sign after virama, no precomposed nukta letters, no zero-width joiners, no mixed scripts |
| Practice words | blocks join back to the word; every block has a writing model |
| Quizzes | correct answer offered, options distinct, odd-one-out explanation names the odd word, rhymes share the ending and non-rhymes don't, letter-sound answers use the letters' own romanization, letter-pair hints are unique, number words and Devanagari digits 0–20 |

## Listening checklist (per clip)

For each clip: ☐ plays · ☐ matches the written text · ☐ clear (no clipping, noise, cut-off) ·
☐ natural standard Hindi pronunciation · ☐ matches the romanization shown in the app.
Record ✅ / ❌ in **Listen** and a note for every ❌.

| Clip | Text | Category | Romanized | Auto | Listen | Notes |
|---|---|---|---|---|---|---|
| `letter_v01` | अ | letter | a | ✅ | ❌ | FAIL — reported as the "3T" item; clip does not sound like short /ə/. Device Hindi voice used instead until re-recorded. |
| `word_v01` | अनार | word |  | ✅ | ☐ |  |
| `letter_v02` | आ | letter | aa | ✅ | ☐ |  |
| `word_v02` | आम | word |  | ✅ | ☐ |  |
| `letter_v03` | इ | letter | i | ✅ | ☐ |  |
| `word_v03` | इमली | word |  | ✅ | ☐ |  |
| `letter_v04` | ई | letter | ee | ✅ | ☐ |  |
| `word_v04` | ईख | word |  | ✅ | ☐ |  |
| `letter_v05` | उ | letter | u | ✅ | ☐ |  |
| `word_v05` | उल्लू | word |  | ✅ | ☐ |  |
| `letter_v06` | ऊ | letter | oo | ✅ | ☐ |  |
| `word_v06` | ऊन | word |  | ✅ | ☐ |  |
| `letter_v07` | ऋ | letter | ri | ✅ | ☐ |  |
| `word_v07` | ऋषि | word |  | ✅ | ☐ |  |
| `letter_v08` | ए | letter | e | ✅ | ☐ |  |
| `word_v08` | एड़ी | word |  | ✅ | ☐ |  |
| `letter_v09` | ऐ | letter | ai | ✅ | ☐ |  |
| `word_v09` | ऐनक | word |  | ✅ | ☐ |  |
| `letter_v10` | ओ | letter | o | ✅ | ☐ |  |
| `word_v10` | ओखली | word |  | ✅ | ☐ |  |
| `letter_v11` | औ | letter | au | ✅ | ☐ |  |
| `word_v11` | औरत | word |  | ✅ | ☐ |  |
| `letter_v12` | अं | letter | an | ✅ | ☐ |  |
| `word_v12` | अंगूर | word |  | ✅ | ☐ |  |
| `letter_v13` | अः | letter | ah | ✅ | ☐ |  |
| `word_v13` | दुःख | word |  | ✅ | ☐ |  |
| `letter_c01` | क | letter | ka | ✅ | ☐ |  |
| `word_c01` | कमल | word |  | ✅ | ☐ |  |
| `letter_c02` | ख | letter | kha | ✅ | ☐ |  |
| `word_c02` | खरगोश | word |  | ✅ | ☐ |  |
| `letter_c03` | ग | letter | ga | ✅ | ☐ |  |
| `word_c03` | गमला | word |  | ✅ | ☐ |  |
| `letter_c04` | घ | letter | gha | ✅ | ☐ |  |
| `word_c04` | घर | word |  | ✅ | ☐ |  |
| `letter_c05` | ङ | letter | nga | ✅ | ☐ |  |
| `word_c05` | अङ्ग | word |  | ✅ | ☐ |  |
| `letter_c06` | च | letter | cha | ✅ | ☐ |  |
| `word_c06` | चम्मच | word |  | ✅ | ☐ |  |
| `letter_c07` | छ | letter | chha | ✅ | ☐ |  |
| `word_c07` | छाता | word |  | ✅ | ☐ |  |
| `letter_c08` | ज | letter | ja | ✅ | ☐ |  |
| `word_c08` | जहाज | word |  | ✅ | ☐ |  |
| `letter_c09` | झ | letter | jha | ✅ | ☐ |  |
| `word_c09` | झंडा | word |  | ✅ | ☐ |  |
| `letter_c10` | ञ | letter | nya | ✅ | ☐ |  |
| `word_c10` | ज्ञान | word |  | ✅ | ☐ |  |
| `letter_c11` | ट | letter | ta | ✅ | ☐ |  |
| `word_c11` | टमाटर | word |  | ✅ | ☐ |  |
| `letter_c12` | ठ | letter | tha | ✅ | ☐ |  |
| `word_c12` | ठेला | word |  | ✅ | ☐ |  |
| `letter_c13` | ड | letter | da | ✅ | ☐ |  |
| `word_c13` | डमरू | word |  | ✅ | ☐ |  |
| `letter_c14` | ढ | letter | dha | ✅ | ☐ |  |
| `word_c14` | ढोल | word |  | ✅ | ☐ |  |
| `letter_c15` | ण | letter | na | ✅ | ☐ |  |
| `word_c15` | बाण | word |  | ✅ | ☐ |  |
| `letter_c16` | त | letter | ta | ✅ | ☐ |  |
| `word_c16` | तरबूज | word |  | ✅ | ☐ |  |
| `letter_c17` | थ | letter | tha | ✅ | ☐ |  |
| `word_c17` | थाली | word |  | ✅ | ☐ |  |
| `letter_c18` | द | letter | da | ✅ | ☐ |  |
| `word_c18` | दवात | word |  | ✅ | ☐ |  |
| `letter_c19` | ध | letter | dha | ✅ | ☐ |  |
| `word_c19` | धनुष | word |  | ✅ | ☐ |  |
| `letter_c20` | न | letter | na | ✅ | ☐ |  |
| `word_c20` | नल | word |  | ✅ | ☐ |  |
| `letter_c21` | प | letter | pa | ✅ | ☐ |  |
| `word_c21` | पतंग | word |  | ✅ | ☐ |  |
| `letter_c22` | फ | letter | pha | ✅ | ☐ |  |
| `word_c22` | फल | word |  | ✅ | ☐ |  |
| `letter_c23` | ब | letter | ba | ✅ | ☐ |  |
| `word_c23` | बकरी | word |  | ✅ | ☐ |  |
| `letter_c24` | भ | letter | bha | ✅ | ☐ |  |
| `word_c24` | भालू | word |  | ✅ | ☐ |  |
| `letter_c25` | म | letter | ma | ✅ | ☐ |  |
| `word_c25` | मछली | word |  | ✅ | ☐ |  |
| `letter_c26` | य | letter | ya | ✅ | ☐ |  |
| `word_c26` | यज्ञ | word |  | ✅ | ☐ |  |
| `letter_c27` | र | letter | ra | ✅ | ☐ |  |
| `word_c27` | रथ | word |  | ✅ | ☐ |  |
| `letter_c28` | ल | letter | la | ✅ | ☐ |  |
| `word_c28` | लड्डू | word |  | ✅ | ☐ |  |
| `letter_c29` | व | letter | va | ✅ | ☐ |  |
| `word_c29` | वन | word |  | ✅ | ☐ |  |
| `letter_c30` | श | letter | sha | ✅ | ☐ |  |
| `word_c30` | शेर | word |  | ✅ | ☐ |  |
| `letter_c31` | ष | letter | shha | ✅ | ☐ |  |
| `word_c31` | षटकोण | word |  | ✅ | ☐ |  |
| `letter_c32` | स | letter | sa | ✅ | ☐ |  |
| `word_c32` | सपेरा | word |  | ✅ | ☐ |  |
| `letter_c33` | ह | letter | ha | ✅ | ☐ |  |
| `word_c33` | हाथी | word |  | ✅ | ☐ |  |
| `letter_c34` | क्ष | letter | ksha | ✅ | ☐ |  |
| `word_c34` | क्षत्रिय | word |  | ✅ | ☐ |  |
| `letter_c35` | त्र | letter | tra | ✅ | ☐ |  |
| `word_c35` | त्रिशूल | word |  | ✅ | ☐ |  |
| `letter_c36` | ज्ञ | letter | gya | ✅ | ☐ |  |
| `word_c36` | ज्ञानी | word |  | ✅ | ☐ |  |
| `matra_aa` | ा | matra |  | ✅ | ☐ |  |
| `matra_i` | ि | matra |  | ✅ | ☐ |  |
| `matra_ee` | ी | matra |  | ✅ | ☐ |  |
| `matra_u` | ु | matra |  | ✅ | ☐ |  |
| `matra_oo` | ू | matra |  | ✅ | ☐ |  |
| `matra_ri` | ृ | matra |  | ✅ | ☐ |  |
| `matra_e` | े | matra |  | ✅ | ☐ |  |
| `matra_ai` | ै | matra |  | ✅ | ☐ |  |
| `matra_o` | ो | matra |  | ✅ | ☐ |  |
| `matra_au` | ौ | matra |  | ✅ | ☐ |  |
| `matra_an` | ं | matra |  | ✅ | ☐ |  |
| `matra_ah` | ः | matra |  | ✅ | ☐ |  |
| `combo_kaa` | का | matra |  | ✅ | ☐ |  |
| `combo_ki` | कि | matra |  | ✅ | ☐ |  |
| `combo_kee` | की | matra |  | ✅ | ☐ |  |
| `combo_ku` | कु | matra |  | ✅ | ☐ |  |
| `combo_koo` | कू | matra |  | ✅ | ☐ |  |
| `combo_kri` | कृ | matra |  | ✅ | ☐ |  |
| `combo_ke` | के | matra |  | ✅ | ☐ |  |
| `combo_kai` | कै | matra |  | ✅ | ☐ |  |
| `combo_ko` | को | matra |  | ✅ | ☐ |  |
| `combo_kau` | कौ | matra |  | ✅ | ☐ |  |
| `combo_kan` | कं | matra |  | ✅ | ☐ |  |
| `combo_kah` | कः | matra |  | ✅ | ☐ |  |
| `num_0` | शून्य | number |  | ✅ | ☐ |  |
| `num_1` | एक | number |  | ✅ | ☐ |  |
| `num_2` | दो | number |  | ✅ | ☐ |  |
| `num_3` | तीन | number |  | ✅ | ☐ |  |
| `num_4` | चार | number |  | ✅ | ☐ |  |
| `num_5` | पाँच | number |  | ✅ | ☐ |  |
| `num_6` | छह | number |  | ✅ | ☐ |  |
| `num_7` | सात | number |  | ✅ | ☐ |  |
| `num_8` | आठ | number |  | ✅ | ☐ |  |
| `num_9` | नौ | number |  | ✅ | ☐ |  |
| `num_10` | दस | number |  | ✅ | ☐ |  |
| `num_11` | ग्यारह | number |  | ✅ | ☐ |  |
| `num_12` | बारह | number |  | ✅ | ☐ |  |
| `num_13` | तेरह | number |  | ✅ | ☐ |  |
| `num_14` | चौदह | number |  | ✅ | ☐ |  |
| `num_15` | पंद्रह | number |  | ✅ | ☐ |  |
| `num_16` | सोलह | number |  | ✅ | ☐ |  |
| `num_17` | सत्रह | number |  | ✅ | ☐ |  |
| `num_18` | अठारह | number |  | ✅ | ☐ |  |
| `num_19` | उन्नीस | number |  | ✅ | ☐ |  |
| `num_20` | बीस | number |  | ✅ | ☐ |  |
| `cw_0` | बिल्ली | word |  | ✅ | ☐ |  |
| `cw_1` | कुत्ता | word |  | ✅ | ☐ |  |
| `cw_2` | बंदर | word |  | ✅ | ☐ |  |
| `cw_3` | गाय | word |  | ✅ | ☐ |  |
| `cw_4` | घोड़ा | word |  | ✅ | ☐ |  |
| `cw_5` | चिड़िया | word |  | ✅ | ☐ |  |
| `cw_6` | मोर | word |  | ✅ | ☐ |  |
| `cw_7` | केला | word |  | ✅ | ☐ |  |
| `cw_8` | सेब | word |  | ✅ | ☐ |  |
| `cw_9` | संतरा | word |  | ✅ | ☐ |  |
| `cw_10` | अनानास | word |  | ✅ | ☐ |  |
| `cw_11` | लाल | word |  | ✅ | ☐ |  |
| `cw_12` | नीला | word |  | ✅ | ☐ |  |
| `cw_13` | हरा | word |  | ✅ | ☐ |  |
| `cw_14` | पीला | word |  | ✅ | ☐ |  |
| `cw_15` | सफ़ेद | word |  | ✅ | ☐ |  |
| `cw_16` | काला | word |  | ✅ | ☐ |  |
| `cw_17` | गुलाबी | word |  | ✅ | ☐ |  |
| `cw_18` | नारंगी | word |  | ✅ | ☐ |  |
| `cw_19` | माता | word |  | ✅ | ☐ |  |
| `cw_20` | पिता | word |  | ✅ | ☐ |  |
| `cw_21` | भाई | word |  | ✅ | ☐ |  |
| `cw_22` | बहन | word |  | ✅ | ☐ |  |
| `cw_23` | दादी | word |  | ✅ | ☐ |  |
| `cw_24` | दादा | word |  | ✅ | ☐ |  |
| `cw_25` | चाचा | word |  | ✅ | ☐ |  |
| `cw_26` | चाची | word |  | ✅ | ☐ |  |
| `cw_27` | मामी | word |  | ✅ | ☐ |  |
| `cw_28` | मामा | word |  | ✅ | ☐ |  |
| `cw_29` | सिर | word |  | ✅ | ☐ |  |
| `cw_30` | हाथ | word |  | ✅ | ☐ |  |
| `cw_31` | पैर | word |  | ✅ | ☐ |  |
| `cw_32` | आँख | word |  | ✅ | ☐ |  |
| `cw_33` | कान | word |  | ✅ | ☐ |  |
| `cw_34` | नाक | word |  | ✅ | ☐ |  |
| `cw_35` | मुँह | word |  | ✅ | ☐ |  |
| `cw_36` | रोटी | word |  | ✅ | ☐ |  |
| `cw_37` | चावल | word |  | ✅ | ☐ |  |
| `cw_38` | दाल | word |  | ✅ | ☐ |  |
| `cw_39` | सब्जी | word |  | ✅ | ☐ |  |
| `cw_40` | दूध | word |  | ✅ | ☐ |  |
| `cw_41` | पानी | word |  | ✅ | ☐ |  |
| `cw_42` | चाय | word |  | ✅ | ☐ |  |
| `cw_43` | नमक | word |  | ✅ | ☐ |  |
| `cw_44` | किताब | word |  | ✅ | ☐ |  |
| `cw_45` | कलम | word |  | ✅ | ☐ |  |
| `cw_46` | कुर्सी | word |  | ✅ | ☐ |  |
| `cw_47` | मेज़ | word |  | ✅ | ☐ |  |
| `cw_48` | दरवाज़ा | word |  | ✅ | ☐ |  |
| `cw_49` | खिड़की | word |  | ✅ | ☐ |  |
| `cw_50` | पैसा | word |  | ✅ | ☐ |  |
| `cw_51` | सूरज | word |  | ✅ | ☐ |  |
| `cw_52` | चाँद | word |  | ✅ | ☐ |  |
| `cw_53` | तारा | word |  | ✅ | ☐ |  |
| `cw_54` | बारिश | word |  | ✅ | ☐ |  |
| `cw_55` | फूल | word |  | ✅ | ☐ |  |
| `cw_56` | पेड़ | word |  | ✅ | ☐ |  |
| `cw_57` | नदी | word |  | ✅ | ☐ |  |
| `cw_58` | पहाड़ | word |  | ✅ | ☐ |  |
| `cw_59` | खाना | word |  | ✅ | ☐ |  |
| `cw_60` | पीना | word |  | ✅ | ☐ |  |
| `cw_61` | लिखना | word |  | ✅ | ☐ |  |
| `cw_62` | पढ़ना | word |  | ✅ | ☐ |  |
| `cw_63` | खेलना | word |  | ✅ | ☐ |  |
| `cw_64` | सोना | word |  | ✅ | ☐ |  |
| `cw_65` | जाना | word |  | ✅ | ☐ |  |
| `cw_66` | आना | word |  | ✅ | ☐ |  |
| `cw_67` | बोलना | word |  | ✅ | ☐ |  |
| `cw_68` | सुनना | word |  | ✅ | ☐ |  |
| `cw_69` | क्र | word |  | ✅ | ☐ |  |
| `cw_70` | प्र | word |  | ✅ | ☐ |  |
| `cw_71` | श्र | word |  | ✅ | ☐ |  |
| `ph_0` | नमस्ते | phrase |  | ✅ | ☐ |  |
| `ph_1` | धन्यवाद | phrase |  | ✅ | ☐ |  |
| `ph_2` | शुक्रिया | phrase |  | ✅ | ☐ |  |
| `ph_3` | अलविदा | phrase |  | ✅ | ☐ |  |
| `ph_4` | हाँ | phrase |  | ✅ | ☐ |  |
| `ph_5` | नहीं | phrase |  | ✅ | ☐ |  |
| `ph_6` | आपका नाम क्या है | phrase |  | ✅ | ☐ |  |
| `ph_7` | मेरा नाम | phrase |  | ✅ | ☐ |  |
| `ph_8` | आप कैसे हैं | phrase |  | ✅ | ☐ |  |
| `ph_9` | मैं ठीक हूँ | phrase |  | ✅ | ☐ |  |
| `ph_10` | शुभ रात्रि | phrase |  | ✅ | ☐ |  |
| `ph_11` | सुप्रभात | phrase |  | ✅ | ☐ |  |
| `ph_12` | यह क्या है | phrase |  | ✅ | ☐ |  |
| `ph_13` | यह कितने का है | phrase |  | ✅ | ☐ |  |
| `ph_14` | मुझे चाहिए | phrase |  | ✅ | ☐ |  |
| `ph_15` | मुझे समझ नहीं आया | phrase |  | ✅ | ☐ |  |
| `ph_16` | कृपया फिर से बोलिए | phrase |  | ✅ | ☐ |  |
| `ph_17` | बहुत अच्छा | phrase |  | ✅ | ☐ |  |
| `ph_18` | शाबाश | phrase |  | ✅ | ☐ |  |
| `ph_19` | फिर से कोशिश करो | phrase |  | ✅ | ☐ |  |
| `ph_20` | सही जवाब | phrase |  | ✅ | ☐ |  |
| `ph_21` | गलत जवाब | phrase |  | ✅ | ☐ |  |
| `ph_22` | सुनिए | phrase |  | ✅ | ☐ |  |
| `ph_23` | लिखिए | phrase |  | ✅ | ☐ |  |
| `ph_24` | पढ़िए | phrase |  | ✅ | ☐ |  |
| `ph_25` | बोलिए | phrase |  | ✅ | ☐ |  |
| `ph_26` | स्कूल जाओ | phrase |  | ✅ | ☐ |  |
| `ph_27` | खेल लो | phrase |  | ✅ | ☐ |  |
| `ph_28` | आओ | phrase |  | ✅ | ☐ |  |
| `ph_29` | जाओ | phrase |  | ✅ | ☐ |  |

## Issues found and fixed (2026-10-28)

| # | Area | Issue | Fix |
|---|---|---|---|
| 1 | Audio | 83 `w_*` and 30 `p_*` catalog ids pointed to files that don't exist; the real recordings (`cw_0…71`, `ph_0…29`) were not listed. Because the text→clip map was "last entry wins", 11 words (अनार, आम, अंगूर, घर, तरबूज, मछली, शेर, हाथी, क्ष, त्र, ज्ञ) were sent to a missing file instead of their real clip. | Catalog repointed to `cw_*` / `ph_*` (order confirmed by clip length vs text length: Spearman 0.68 words / 0.90 phrases, vs ≈0 for other orderings), 11 duplicate entries removed, lookup is now first-wins. **Still needs a listening pass** (checklist above). |
| 2 | Audio | `letter_v01` (अ) listed twice. | Duplicate removed. |
| 3 | Audio | अ clip reported wrong (the "3T" item). | Marked failed in `lib/data/audio_qa.dart`; the device Hindi voice speaks it instead when installed (bundled clip is the fallback). **Needs a re-recorded clip** — drop it in as `assets/audio/letter_v01.mp3` and remove the id from `audioClipsFailedQa`. |
| 4 | Letters | ङ's example word अंग is spelled with the anusvara, so it doesn't contain ङ. | Spelled अङ्ग (same word, same sound, same clip). |
| 5 | Letters | Vowel pronunciation hints were vague or misleading (उ "oo (short)", ऊ "ooo", ई "eee", इ "ih"). | Replaced with English key words: u as in put, oo as in moon, ee as in see, i as in sit, a as in about, … |
| 6 | Letter sound quiz | ई answer was "ii" while the app teaches "ee". | Uses "ee". |
| 7 | Letter pairs | ट/ठ and त/थ (and ड/ढ, द/ध) had identical hints. | Hard (tongue curled back) vs soft (tongue on the teeth). |
| 8 | Odd one out | कमल listed twice and every word started with क; बिल्ली listed twice and the answer index pointed at कुत्ता while the explanation said कबूतर; "लाल पीला नीला हरा" had no odd word; दाल was marked as not rhyming with -ाल; explanation said घोड़ा starts with ग. | All five sets corrected. |
| 9 | Rhymes | Non-words or non-rhymes given as rhymes (मिन, खात, नीत, बीट, चपना, दानी/खानी, फल for बाल); ताज listed as *not* rhyming with राज. | Replaced with common rhyming words (बिन/गिन, सात, जीत/मीत, अपना/जपना, रानी/नानी, गाल), ताज → महल. |
| 10 | Fill in the blank | Made-up distractor गाम. | आम. |

## Release gate

- [ ] `flutter test` passes (includes the automated audit).
- [ ] Every clip in the table has **Listen = ✅**, or a ❌ with an open ticket.
- [ ] Any re-recorded clip is re-listened in the app on Android, iOS and web.
