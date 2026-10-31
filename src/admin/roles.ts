/**
 * 后台角色 (tech plan S25; the owner: admin具备超级权限，manager可以进行权限分配，但是不能对用户的数据进行操作。integrator可以进入
 * 后台面板，但是只能对邮件和短信系统进行操作; S36: 「把integrator改成editor-》网站编辑」, the integrator is editor). Each staff
 * role has its capabilities; every admin route asks for one, and the dashboard shows what the caller's role may do
 * (GET /v1/admin/me).
 */
import type { AccountRole, UserRecord } from "../auth/service.js";

export const STAFF_ROLES = ["editor", "manager", "admin"] as const;
export type StaffRole = (typeof STAFF_ROLES)[number];

/**
 * - view: the dashboard's numbers, the accounts and an account's page;
 * - assign: roles and permissions (停用, AI, 充值);
 * - user_data: what changes or takes a user's data: 增加积分, 在所有设备上退出, the exports;
 * - messages: the mail and SMS templates, their previews, test sends and the dispatch log;
 * - content: 内容管理 (S29), the app's texts and images;
 * - settings: 设置 (S31), what config/settings.json and .env set, the AI switches among them.
 */
export type Capability = "view" | "assign" | "user_data" | "messages" | "content" | "settings";

export const CAPABILITIES: Record<StaffRole, readonly Capability[]> = {
  admin: ["view", "assign", "user_data", "messages", "content", "settings"],
  manager: ["view", "assign"],
  // 内容管理 (S29) to begin with for admin and editor, the roles that word what users read; the owner can change it.
  editor: ["messages", "content"],
};

/** Whether [u] is named, by its username or its email, in the server's MINGLI_ADMINS ([admins], in lower case). */
export const namedInConfig = (admins: ReadonlySet<string>, u: UserRecord) =>
  [u.username, u.email].some((n) => !!n && admins.has(n.toLowerCase()));

/** The staff role of [u]: an admin by the server's MINGLI_ADMINS ([byConfig]) whatever the record says. */
export function staffRoleOf(u: UserRecord, byConfig: boolean): StaffRole | undefined {
  if (byConfig) return "admin";
  return (STAFF_ROLES as readonly string[]).includes(u.role ?? "") ? (u.role as StaffRole) : undefined;
}

export const can = (role: StaffRole, what: Capability) => CAPABILITIES[role].includes(what);

/** The roles [role] may give, and take: an admin any; a manager any but admin. */
export function assignableRoles(role: StaffRole): AccountRole[] {
  if (role === "admin") return ["user", "editor", "manager", "admin"];
  if (role === "manager") return ["user", "editor", "manager"];
  return [];
}

export const ACCOUNT_ROLES: readonly AccountRole[] = ["user", "editor", "manager", "admin"];
