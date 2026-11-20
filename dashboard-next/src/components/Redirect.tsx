import Link from "next/link";
import { BASE } from "./ui";

// Old dashboard URLs keep working: a static page that forwards to the new location.
export default function Redirect({ to, label }: { to: string; label: string }) {
  return (
    <>
      <meta httpEquiv="refresh" content={`0; url=${BASE}${to}`} />
      <div className="col prose" style={{ padding: "4rem 0" }}>
        <p>
          This page moved to <Link href={to}>{label}</Link>.
        </p>
      </div>
    </>
  );
}
