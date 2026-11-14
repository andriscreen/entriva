ALTER TABLE public.profiles
ADD COLUMN avatar_path TEXT NOT NULL DEFAULT '/avatar/avatar1.jpg'
CONSTRAINT profiles_avatar_path_check
CHECK (avatar_path ~ '^/avatar/avatar([1-9]|1[0-8])[.]jpg$');
