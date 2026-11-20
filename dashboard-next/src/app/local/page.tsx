import Redirect from "@/components/Redirect";

export const metadata = { title: "Moved", robots: { index: false } };

export default function Page() {
  return <Redirect to="/studies/local-4070/" label="Coding agents on a 12 GB consumer GPU" />;
}
