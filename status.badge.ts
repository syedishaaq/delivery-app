import { OrderStatus } from "../backend.d";

interface StatusBadgeProps {
  status: OrderStatus;
  size?: "sm" | "md";
}

const STATUS_CONFIG: Record<OrderStatus, { label: string; className: string; emoji: string }> = {
  [OrderStatus.pending]: {
    label: "Pending",
    className: "status-pending",
    emoji: "⏳",
  },
  [OrderStatus.accepted]: {
    label: "Accepted",
    className: "status-accepted",
    emoji: "✅",
  },
  [OrderStatus.pickedUp]: {
    label: "On the Way",
    className: "status-pickedUp",
    emoji: "🛵",
  },
  [OrderStatus.delivered]: {
    label: "Delivered",
    className: "status-delivered",
    emoji: "🎉",
  },
  [OrderStatus.cancelled]: {
    label: "Cancelled",
    className: "status-cancelled",
    emoji: "❌",
  },
};

export default function StatusBadge({ status, size = "sm" }: StatusBadgeProps) {
  const config = STATUS_CONFIG[status] ?? {
    label: status,
    className: "status-pending",
    emoji: "•",
  };

  return (
    <span
      className={`
        inline-flex items-center gap-1 font-medium rounded-full whitespace-nowrap
        ${config.className}
        ${size === "sm" ? "text-[10px] px-2 py-0.5" : "text-xs px-2.5 py-1"}
      `}
    >
      {config.emoji} {config.label}
    </span>
  );
}
