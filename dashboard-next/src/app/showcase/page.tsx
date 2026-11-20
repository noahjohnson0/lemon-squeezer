import Redirect from "@/components/Redirect";

export const metadata = { title: "Moved", robots: { index: false } };

export default function Page() {
  return <Redirect to="/studies/" label="Studies" />;
}
