import Redirect from "@/components/Redirect";

export const metadata = { title: "Moved", robots: { index: false } };

export default function Page() {
  return <Redirect to="/studies/tool-calling-week/" label="Big local models as tool-calling agents" />;
}
