import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Architecture — DevOps Platform on AWS EKS",
};

const PIPELINE_STEPS = [
  "GitHub",
  "GitHub Actions",
  "Tests / Validation",
  "Docker Build",
  "AWS ECR",
  "Terraform",
  "AWS EKS",
  "Kubernetes / Helm",
  "This application",
  "Monitoring",
];

const AWS_LAYERS = [
  {
    title: "Network",
    items: ["1 VPC", "Public subnets across 2 availability zones", "Internet Gateway", "Restrictive Security Groups"],
  },
  {
    title: "Compute",
    items: ["EKS control plane (AWS managed)", "1 managed node group", "AWS Load Balancer Controller (ALB Ingress)"],
  },
  {
    title: "Identity",
    items: [
      "IAM roles for the EKS cluster and node group",
      "IRSA for the application and the Load Balancer Controller",
      "OIDC trust between GitHub Actions and a scoped IAM role",
    ],
  },
  {
    title: "Registry",
    items: ["1 ECR repository, images tagged by commit SHA, no reliance on latest"],
  },
];

export default function ArchitecturePage() {
  return (
    <div className="mx-auto max-w-5xl px-6 py-16">
      <p className="text-sm font-medium text-accent">Architecture</p>
      <h1 className="mt-2 text-3xl font-semibold tracking-tight">
        From a git push to a running, observed service
      </h1>
      <p className="mt-4 max-w-2xl text-muted">
        The platform favors a small set of coherent, production-representative
        components over an exhaustive tool list. Every box below is a real
        piece of this deployment, not an aspirational diagram.
      </p>

      <section className="mt-12">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-muted">
          Delivery pipeline
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
          AWS layout (low-cost profile)
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
          No NAT Gateway: the cluster runs in public subnets with restrictive
          Security Groups to keep costs near zero when the infrastructure is
          destroyed between work sessions. Full diagrams and the reasoning
          behind this trade-off are documented in the repository README.
        </p>
      </section>
    </div>
  );
}
