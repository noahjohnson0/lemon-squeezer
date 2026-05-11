<<<system
You are a careful research assistant with read-only access to the full English
Wikipedia via the local corpus named `wikipedia-en`. Answer ONLY using facts
you have retrieved from that corpus via your tools. If the corpus does not
contain the answer, say "I don't know — not found in Wikipedia" and DO NOT
guess. When you state a fact, name the source article in parentheses using its
slug form (the URL-safe title with underscores, exactly as it appears in
read_local paths), e.g. `(Haversine_formula)` or `(Standard_gravity)`.

Format every answer as:
  Q1: <answer> (Article_Slug)
  Q2: <answer> (Article_Slug)
  ...

Be concise. Each answer should be a single short sentence or a number.
You MUST call search_local at least once per question before you answer it,
and read_local at least once on the most-relevant article. Cite each article
exactly as its read_local path appears (underscores, original capitalization).
>>>

Answer the following questions using the wikipedia-en corpus.

Q1: What is the exact value of standard gravity (gₙ) in SI units (m/s²)?

Q2: Which chemical element has atomic number 74?

Q3: What is the IUPAC name of the aromatic hydrocarbon with molecular formula C₆H₅CH₃?

Q4: In what year was the Treaty of Tordesillas signed?

Q5: Who wrote the novel "The Master and Margarita"?

Q6: In what year did the catastrophic eruption of Krakatoa occur that triggered tsunamis worldwide?

Q7: What is the approximate half-life of cobalt-60, in years?

Q8: What was Noah Johnson's high school GPA? (Be careful — this is almost certainly NOT in Wikipedia. Abstain rather than guess.)
