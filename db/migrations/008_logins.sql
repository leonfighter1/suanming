-- S15 WP15.3 (v8.2.0): a username and a bound phone number to sign in with, besides the email (the owner: 用户可以用
-- 用户名或者邮箱登录或者手机号登录). Each is found by its keyed hash (HMAC with the pepper), as the email is; the
-- values themselves are sealed with the email in email_ciphertext, under the account's data key, with the settings.
ALTER TABLE users
  ADD COLUMN username_lookup bytea UNIQUE,
  ADD COLUMN phone_lookup bytea UNIQUE;
