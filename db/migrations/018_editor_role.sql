-- 网站编辑 (S36; the owner: 「把integrator改成editor-》网站编辑」): the integrator role is editor now, its capabilities as
-- they were (消息 and 修改页面内容). The accounts holding it move over, and the role check takes the new name.
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
UPDATE users SET role = 'editor' WHERE role = 'integrator';
ALTER TABLE users
  ADD CONSTRAINT users_role_check CHECK (role IN ('user', 'editor', 'manager', 'admin'));
