import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Architecture — DevOps Platform on AWS EKS",
};

const PIPELINE_STEPS = [
  "GitHub",
  "GitHub Actions",
  "Tests / Validation",
  "Build Docker",
  "AWS ECR",
  "Terraform",
  "AWS EKS",
  "Kubernetes / Helm",
  "Cette application",
  "Monitoring",
];

const AWS_LAYERS = [
  {
    title: "Réseau",
    items: ["1 VPC", "Subnets publics sur 2 zones de disponibilité", "Internet Gateway", "Security Groups restrictifs"],
  },
  {
    title: "Compute",
    items: ["Control plane EKS (managé par AWS)", "1 node group managé", "AWS Load Balancer Controller (Ingress ALB)"],
  },
  {
    title: "Identité",
    items: [
      "Rôles IAM pour le cluster EKS et le node group",
      "IRSA pour l'application et le Load Balancer Controller",
      "Confiance OIDC entre GitHub Actions et un rôle IAM scopé",
    ],
  },
  {
    title: "Registre",
    items: ["1 repository ECR, images taguées par SHA de commit, jamais uniquement latest"],
  },
];

export default function ArchitecturePage() {
  return (
    <div className="mx-auto max-w-5xl px-6 py-16">
      <p className="text-sm font-medium text-accent">Architecture</p>
      <h1 className="mt-2 text-3xl font-semibold tracking-tight">
        D&apos;un git push à un service déployé et observé
      </h1>
      <p className="mt-4 max-w-2xl text-muted">
        La plateforme privilégie un petit nombre de composants cohérents,
        représentatifs d&apos;un usage de production, plutôt qu&apos;une liste
        exhaustive d&apos;outils. Chaque étape ci-dessous est un élément réel
        de ce déploiement, pas un schéma aspirationnel.
      </p>

      <section className="mt-12">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-muted">
          Chaîne de livraison
        </h2>
        <div className="mt-5 flex flex-wrap items-center gap-2">
          {PIPELINE_STEPS.map((step, index) => (
            <div key={step} className="flex items-center gap-2">
              <span className="card px-3 py-1.5 text-sm">{step}</span>
              {index < PIPELINE_STEPS.length - 1 && (
                <span className="text-muted" aria-hidden>
                  &rarr;
                </span>
              )}
            </div>
          ))}
        </div>
      </section>

      <section className="mt-14">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-muted">
          Architecture AWS (profil low-cost)
        </h2>
        <div className="mt-5 grid gap-4 sm:grid-cols-2">
          {AWS_LAYERS.map((layer) => (
            <div key={layer.title} className="card p-5">
              <h3 className="text-sm font-semibold">{layer.title}</h3>
              <ul className="mt-3 space-y-1.5 text-sm text-muted">
                {layer.items.map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ul>
            </div>
          ))}
        </div>
        <p className="mt-5 text-sm text-muted">
          Pas de NAT Gateway : le cluster tourne dans des subnets publics avec
          des Security Groups restrictifs, pour garder un coût proche de zéro
          lorsque l&apos;infrastructure est détruite entre les sessions de
          travail. Les diagrammes complets et le raisonnement derrière ce
          compromis sont documentés dans le README du repository.
        </p>
      </section>
    </div>
  );
}
