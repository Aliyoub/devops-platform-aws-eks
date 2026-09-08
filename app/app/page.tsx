import Link from "next/link";

const STACK = [
  "AWS",
  "Terraform",
  "Docker",
  "Kubernetes",
  "Helm",
  "GitHub Actions",
  "Prometheus",
  "Grafana",
];

const SKILLS = [
  {
    title: "Cloud infrastructure",
    description:
      "VPC, subnets, IAM and EKS provisioned and versioned entirely with Terraform.",
  },
  {
    title: "Container platform",
    description:
      "A multi-stage, non-root Docker image deployed on Kubernetes via a Helm chart.",
  },
  {
    title: "CI/CD",
    description:
      "GitHub Actions pipeline authenticating to AWS through OIDC, no static credentials.",
  },
  {
    title: "Security",
    description:
      "Least-privilege RBAC, restrictive SecurityContext, NetworkPolicy and image scanning.",
  },
  {
    title: "Observability",
    description:
      "Prometheus and Grafana dashboards covering CPU, memory, pods and availability.",
  },
  {
    title: "Operations",
    description:
      "Real, reproduced incident scenarios and a tested disaster recovery procedure.",
  },
];

export default function Home() {
  return (
    <div className="mx-auto max-w-5xl px-6">
      <section className="flex flex-col gap-6 py-20">
        <p className="text-sm font-medium text-accent">
          Personal portfolio project &mdash; Aliyoub
        </p>
        <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">
          A DevOps platform, deployed for real on AWS EKS.
        </h1>
        <p className="max-w-2xl text-lg text-muted">
          This application is the working demo behind a full DevOps/Cloud
          platform: infrastructure as code, a containerized service running
          on Kubernetes, an automated CI/CD pipeline, security hardening and
          observability &mdash; not a tutorial, a system that was actually run.
        </p>
        <div className="flex flex-wrap gap-3 pt-2">
          <Link
            href="/architecture"
            className="rounded-lg bg-accent px-4 py-2 text-sm font-medium text-accent-foreground transition-opacity hover:opacity-90"
          >
            View the architecture
          </Link>
          <a
            href="https://github.com/Aliyoub/devops-platform-aws-eks"
            target="_blank"
            rel="noreferrer"
            className="rounded-lg border border-border px-4 py-2 text-sm font-medium transition-colors hover:bg-surface-muted"
          >
            Source on GitHub
          </a>
        </div>
      </section>

      <section className="border-t border-border py-14">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-muted">
          Why this project
        </h2>
        <p className="mt-4 max-w-2xl text-base leading-relaxed">
          Built to demonstrate, with real evidence rather than claims, the
          ability to design, automate, deploy, secure, observe, diagnose and
          maintain a cloud platform &mdash; the day-to-day work of a DevOps /
          Cloud / Platform Engineer, and a practical companion to CKA
          preparation.
        </p>
      </section>

      <section className="border-t border-border py-14">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-muted">
          Stack
        </h2>
        <ul className="mt-4 flex flex-wrap gap-2">
          {STACK.map((tech) => (
            <li
              key={tech}
              className="card rounded-full px-3 py-1.5 text-sm text-foreground"
            >
              {tech}
            </li>
          ))}
        </ul>
      </section>

      <section className="border-t border-border py-14">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-muted">
          Skills demonstrated
        </h2>
        <div className="mt-6 grid gap-4 sm:grid-cols-2">
          {SKILLS.map((skill) => (
            <div key={skill.title} className="card p-5">
              <h3 className="text-sm font-semibold">{skill.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-muted">
                {skill.description}
              </p>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
