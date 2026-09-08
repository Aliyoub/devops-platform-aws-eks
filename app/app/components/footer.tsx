export default function Footer() {
  return (
    <footer className="border-t border-border">
      <div className="mx-auto flex max-w-5xl flex-col gap-2 px-6 py-8 text-xs text-muted sm:flex-row sm:items-center sm:justify-between">
        <p>DevOps Platform &mdash; Aliyoub</p>
        <p>
          Construit avec Next.js, Terraform, Docker, Kubernetes, Helm, GitHub
          Actions, Prometheus et Grafana.
        </p>
      </div>
    </footer>
  );
}
