import Link from "next/link";
import { STUDIES } from "@/lib/studies";
import { Chip } from "./ui";

export default function StudyCards() {
  return (
    <div className="studies">
      {STUDIES.map((s) => (
        <Link key={s.href} href={s.href} className="study-card">
          <div className="chips">
            {s.status.map((st) => (
              <Chip key={st} s={st} />
            ))}
          </div>
          <h3>{s.title}</h3>
          <p>{s.blurb}</p>
          <div className="meta">
            {s.venue} · {s.when}
          </div>
        </Link>
      ))}
    </div>
  );
}
