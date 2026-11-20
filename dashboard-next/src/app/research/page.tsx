import type { Metadata } from "next";
import Link from "next/link";
import { DataTable } from "@/components/ui";
import { BAR_TEXT, LINES, cleared, type BarItem } from "@/lib/research";

export const metadata: Metadata = {
  title: "Research",
  description:
    "The research track: questions on mixture-of-experts routing, expert pruning and unusual hardware, each listed with its status against a publication bar.",
};

function Bar({ label, item }: { label: string; item: BarItem }) {
  return (
    <li>
      <span className={`st ${item.s}`}>{BAR_TEXT[item.s]}</span>
      <span className="d">
        <strong>{label}.</strong> {item.d}
      </span>
    </li>
  );
}

export default function Research() {
  const papers = LINES.filter((l) => cleared(l) && l.paper);
  return (
    <>
      <header className="study-head col-wide">
        <div className="col" style={{ marginLeft: 0 }}>
          <div className="kicker">Research track</div>
          <h1>Research</h1>
          <p className="dek">
            This track holds the work that asks a question with no published answer that we could find. It is kept apart from the benchmarks
            because it is held to a different bar, and a result is written up as a paper when it clears that bar.
          </p>
        </div>
        <nav className="toc" aria-label="On this page">
          <a href="#bar">The bar</a>
          <a href="#tracks">How it differs from the benchmarks</a>
          <a href="#lines">Lines of work</a>
          <a href="#papers">Papers</a>
        </nav>
      </header>

      <div className="col prose">
        <h2 id="bar">The bar</h2>
        <p>A research claim is published here when all three of the following hold.</p>
        <ol>
          <li>
            <strong>Related-work check.</strong> A written search of papers and public repositories found no earlier report of the same
            result. The search and what it did not cover are part of the paper.
          </li>
          <li>
            <strong>An effect with an interval.</strong> The claimed difference has a 95% interval that excludes zero, on a measure that was
            fixed before the runs. A null result is published only when its interval is narrow enough to rule out an effect of useful size.
          </li>
          <li>
            <strong>Replicated.</strong> The effect was seen again on a second set of seeds and on a second model, scale or machine.
          </li>
        </ol>
        <p>
          A line that has not cleared all three is listed below with the question it asks and where it stands. No result is stated for
          it. The numbers stay in the lab until the paper is written.
        </p>

        <h2 id="tracks">How it differs from the benchmarks</h2>
      </div>
      <div className="col-wide">
        <DataTable
          head={["", "Benchmarks", "Research"]}
          rows={[
            ["Goal", "Say what works locally, on which hardware, for which job", "Find and report effects that are not already published"],
            ["A claim is", "A ranking or a recommendation with an interval, a cost and a speed", "A new effect with an interval, replicated"],
            ["Novelty", "Not required. A known result measured on current models is useful", "Required, with a related-work check"],
            ["Format", "Study pages built from public run data", "Papers"],
            ["Unfinished work", "Shown and labelled as exploration", "Listed as a question, with no numbers"],
          ]}
        />
      </div>

      <div className="col-wide">
        <h2 id="lines">Lines of work</h2>
        <div className="lines">
          {LINES.map((l) => (
            <section className="line" key={l.slug} id={l.slug}>
              <div>
                <div className="state">{l.state}</div>
                <h3>{l.title}</h3>
                <p className="q">{l.question}</p>
                <p className="where">{l.setup}</p>
                {cleared(l) && l.paper && (
                  <p>
                    <Link href={l.paper}>Read the paper</Link>
                  </p>
                )}
              </div>
              <ul className="barlist" aria-label="Status against the bar">
                <Bar label="Related work" item={l.related} />
                <Bar label="Effect with an interval" item={l.effect} />
                <Bar label="Replicated" item={l.replicated} />
              </ul>
            </section>
          ))}
        </div>
      </div>

      <div className="col prose">
        <h2 id="papers">Papers</h2>
        {papers.length === 0 ? (
          <p>No line has cleared the bar yet, so no paper is published. The first one will be linked here and from its line above.</p>
        ) : (
          <ul>
            {papers.map((l) => (
              <li key={l.slug}>
                <Link href={l.paper!}>{l.title}</Link>
              </li>
            ))}
          </ul>
        )}
        <p>
          The measured, practical work is on the <Link href="/">benchmarks</Link> track.
        </p>
      </div>
    </>
  );
}
