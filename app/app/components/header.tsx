import Link from "next/link";
import EnvBadge from "./env-badge";

export default function Header() {
  return (
    <header className="border-b border-border">
      <div className="mx-auto flex max-w-5xl items-center justify-between px-6 py-4">
        <Link href="/" className="flex flex-col leading-tight">
          <span className="text-sm font-semibold tracking-tight">
            DevOps Platform
          </span>
          <span className="text-xs text-muted">on AWS EKS</span>
        </Link>

        <nav className="flex items-center gap-6 text-sm">
          <Link href="/" className="text-muted transition-colors hover:text-foreground">
            Home
          </Link>
          <Link
            href="/architecture"
            className="text-muted transition-colors hover:text-foreground"
          >
            Architecture
          </Link>
          <a
            href="https://github.com/Aliyoub/devops-platform-aws-eks"
            target="_blank"
            rel="noreferrer"
            className="text-muted transition-colors hover:text-foreground"
          >
            GitHub
          </a>
          <EnvBadge />
        </nav>
      </div>
    </header>
  );
}
