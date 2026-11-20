import type { Metadata } from "next";
import StudyCards from "@/components/StudyCards";

export const metadata: Metadata = {
  title: "Studies",
  description: "One page per study: question, method, results with intervals, limitations and data.",
};

export default function Studies() {
  return (
    <>
      <header className="study-head col-wide">
        <div className="col" style={{ marginLeft: 0 }}>
          <div className="kicker">Studies</div>
          <h1>Studies</h1>
          <p className="dek">
            Each study has its own page with the question, the method, the results with intervals, the limitations and links to its rows. The
            label on each card says how far to trust it today.
          </p>
        </div>
      </header>
      <div className="col-wide">
        <StudyCards />
      </div>
    </>
  );
}
