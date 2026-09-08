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
    title: "Infrastructure cloud",
    description:
      "VPC, subnets, IAM et EKS provisionnés et versionnés entièrement avec Terraform.",
  },
  {
    title: "Plateforme conteneurs",
    description:
      "Une image Docker multi-stage, non-root, déployée sur Kubernetes via un chart Helm.",
  },
  {
    title: "CI/CD",
    description:
      "Pipeline GitHub Actions authentifié à AWS via OIDC, sans credential statique.",
  },
  {
    title: "Sécurité",
    description:
      "RBAC least-privilege, SecurityContext restrictif, NetworkPolicy et scan d'image.",
  },
  {
    title: "Observabilité",
    description:
      "Dashboards Prometheus et Grafana couvrant CPU, mémoire, pods et disponibilité.",
  },
  {
    title: "Exploitation",
    description:
      "Des incidents réellement reproduits et une procédure de disaster recovery testée.",
  },
];

export default function Home() {
  return (
    <div className="mx-auto max-w-5xl px-6">
      <section className="flex flex-col gap-6 py-20">
        <p className="text-sm font-medium text-accent">
          Projet personnel &mdash; Aliyoub
        </p>
        <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">
          Une plateforme DevOps, réellement déployée sur AWS EKS.
        </h1>
        <p className="max-w-2xl text-lg text-muted">
          Cette application est la démo réelle derrière une plateforme
          DevOps/Cloud complète : infrastructure as code, un service
          conteneurisé sur Kubernetes, un pipeline CI/CD automatisé, une
          sécurité durcie et de l&apos;observabilité &mdash; pas un tutoriel,
          un système qui a vraiment tourné.
        </p>
        <div className="flex flex-wrap gap-3 pt-2">
          <Link
            href="/architecture"
            className="rounded-lg bg-accent px-4 py-2 text-sm font-medium text-accent-foreground transition-opacity hover:opacity-90"
          >
            Voir l&apos;architecture
          </Link>
          <a
            href="https://github.com/Aliyoub/devops-platform-aws-eks"
            target="_blank"
            rel="noreferrer"
            className="rounded-lg border border-border px-4 py-2 text-sm font-medium transition-colors hover:bg-surface-muted"
          >
            Code source sur GitHub
          </a>
        </div>
      </section>

      <section className="border-t border-border py-14">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-muted">
          Pourquoi ce projet
        </h2>
        <p className="mt-4 max-w-2xl text-base leading-relaxed">
          Construit pour démontrer, avec des preuves réelles plutôt que des
          affirmations, la capacité à concevoir, automatiser, déployer,
          sécuriser, observer, diagnostiquer et maintenir une plateforme
          cloud &mdash; le travail quotidien d&apos;un DevOps / Cloud /
          Platform Engineer, et un complément pratique à la préparation du
          CKA.
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
          Compétences démontrées
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
