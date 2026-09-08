const ENVIRONMENT_STYLES: Record<string, string> = {
  production: "bg-success-soft text-success border-success/30",
  staging: "bg-accent-soft text-accent border-accent/30",
  dev: "bg-surface-muted text-muted border-border",
  local: "bg-surface-muted text-muted border-border",
};

export default function EnvBadge() {
  const environment = process.env.APP_ENV ?? "local";
  const style = ENVIRONMENT_STYLES[environment] ?? ENVIRONMENT_STYLES.local;

  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs font-medium ${style}`}
    >
      <span className="h-1.5 w-1.5 rounded-full bg-current" />
      {environment}
    </span>
  );
}
