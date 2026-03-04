-- ============================================================
-- 100 Gaming Reaction Emojis (Discord/Sleeper-style)
-- Categories: core, hype, fail, watching, gaming, memes, social
-- ============================================================

-- Add category and sort_order columns to reaction_types
ALTER TABLE public.reaction_types
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'core',
  ADD COLUMN IF NOT EXISTS sort_order int NOT NULL DEFAULT 0;

-- Clear existing reactions and types (pre-launch, test data only)
DELETE FROM public.reactions;
DELETE FROM public.reaction_types;

-- ========================
-- CORE EMOTIONS (15)
-- ========================
INSERT INTO public.reaction_types (slug, display_name, emoji, category, sort_order) VALUES
  ('laugh',        'Laughing',     '😂', 'core', 1),
  ('cry',          'Crying',       '😭', 'core', 2),
  ('angry',        'Angry',        '😡', 'core', 3),
  ('thinking',     'Thinking',     '🤔', 'core', 4),
  ('fire',         'Fire',         '🔥', 'core', 5),
  ('shocked',      'Shocked',      '😱', 'core', 6),
  ('heart_eyes',   'Heart Eyes',   '😍', 'core', 7),
  ('pleading',     'Pleading',     '🥺', 'core', 8),
  ('frustrated',   'Frustrated',   '😤', 'core', 9),
  ('mind_blown',   'Mind Blown',   '🤯', 'core', 10),
  ('clap',         'Clap',         '👏', 'core', 11),
  ('raised_hands', 'Raised Hands', '🙌', 'core', 12),
  ('grimace',      'Grimace',      '😬', 'core', 13),
  ('salute',       'Salute',       '🫡', 'core', 14),
  ('smirk',        'Smirk',        '😏', 'core', 15);

-- ========================
-- HYPE (15)
-- ========================
INSERT INTO public.reaction_types (slug, display_name, emoji, category, sort_order) VALUES
  ('hundred',      '100',          '💯', 'hype', 1),
  ('rocket',       'Rocket',       '🚀', 'hype', 2),
  ('crown',        'Crown',        '👑', 'hype', 3),
  ('galaxy_brain', 'Galaxy Brain', '🧠', 'hype', 4),
  ('bullseye',     'Bullseye',     '🎯', 'hype', 5),
  ('trophy',       'Trophy',       '🏆', 'hype', 6),
  ('lightning',    'Lightning',    '⚡', 'hype', 7),
  ('diamond',      'Diamond',      '💎', 'hype', 8),
  ('crystal_ball', 'Crystal Ball', '🔮', 'hype', 9),
  ('party',        'Party',        '🎉', 'hype', 10),
  ('praise',       'Praise',       '🙏', 'hype', 11),
  ('flex',         'Flex',         '💪', 'hype', 12),
  ('clutch',       'CLUTCH',       '🫴', 'hype', 13),
  ('insane',       'INSANE',       '🤩', 'hype', 14),
  ('gold_medal',   'Gold Medal',   '🥇', 'hype', 15);

-- ========================
-- FAIL / SALT (15)
-- ========================
INSERT INTO public.reaction_types (slug, display_name, emoji, category, sort_order) VALUES
  ('skull',        'Skull',        '💀', 'fail', 1),
  ('rip',          'RIP',          '🪦', 'fail', 2),
  ('clown',        'Clown',        '🤡', 'fail', 3),
  ('trash',        'Trash',        '🗑️', 'fail', 4),
  ('down_bad',     'Down Bad',     '📉', 'fail', 5),
  ('salt',         'Salt',         '🧂', 'fail', 6),
  ('skill_issue',  'SKILL ISSUE',  '🎮', 'fail', 7),
  ('melting',      'Melting',      '🫠', 'fail', 8),
  ('poop',         'Poop',         '💩', 'fail', 9),
  ('red_flag',     'Red Flag',     '🚩', 'fail', 10),
  ('big_l',        'L',            '🅱️', 'fail', 11),
  ('thumbs_down',  'Thumbs Down',  '👎', 'fail', 12),
  ('facepalm',     'Facepalm',     '🤦', 'fail', 13),
  ('dizzy',        'Dizzy',        '😵', 'fail', 14),
  ('cringe',       'CRINGE',       '😖', 'fail', 15);

-- ========================
-- WATCHING (10)
-- ========================
INSERT INTO public.reaction_types (slug, display_name, emoji, category, sort_order) VALUES
  ('eyes',         'Eyes',         '👀', 'watching', 1),
  ('popcorn',      'Popcorn',      '🍿', 'watching', 2),
  ('spy',          'Spy',          '🔭', 'watching', 3),
  ('detective',    'Detective',    '🕵️', 'watching', 4),
  ('tea',          'Tea',          '🫖', 'watching', 5),
  ('hmm',          'HMM?',         '🧐', 'watching', 6),
  ('shush',        'Shush',        '🤫', 'watching', 7),
  ('notepad',      'Notepad',      '📝', 'watching', 8),
  ('twist',        'TWIST',        '🔄', 'watching', 9),
  ('scales',       'Scales',       '⚖️', 'watching', 10);

-- ========================
-- GAMING (20)
-- ========================
INSERT INTO public.reaction_types (slug, display_name, emoji, category, sort_order) VALUES
  ('controller',   'Controller',   '🎮', 'gaming', 1),
  ('swords',       'Swords',       '⚔️', 'gaming', 2),
  ('shield',       'Shield',       '🛡️', 'gaming', 3),
  ('gem',          'Gem',          '💎', 'gaming', 4),
  ('potion',       'Potion',       '🧪', 'gaming', 5),
  ('headset',      'Headset',      '🎧', 'gaming', 6),
  ('bow',          'Bow',          '🏹', 'gaming', 7),
  ('dagger',       'Dagger',       '🗡️', 'gaming', 8),
  ('dice',         'Dice',         '🎲', 'gaming', 9),
  ('joystick',     'Joystick',     '🕹️', 'gaming', 10),
  ('bomb',         'Bomb',         '💣', 'gaming', 11),
  ('wizard',       'Wizard',       '🧙', 'gaming', 12),
  ('dragon',       'Dragon',       '🐉', 'gaming', 13),
  ('alien',        'Alien',        '👾', 'gaming', 14),
  ('crosshair',    'Crosshair',    '🎯', 'gaming', 15),
  ('map',          'Map',          '🗺️', 'gaming', 16),
  ('castle',       'Castle',       '🏰', 'gaming', 17),
  ('star',         'Star',         '⭐', 'gaming', 18),
  ('key',          'Key',          '🔑', 'gaming', 19),
  ('medal',        'Medal',        '🏅', 'gaming', 20);

-- ========================
-- MEMES (15)
-- ========================
INSERT INTO public.reaction_types (slug, display_name, emoji, category, sort_order) VALUES
  ('based',        'BASED',        '🅱️', 'memes', 1),
  ('mot',          'MOT',          '🏍️', 'memes', 2),
  ('touch_grass',  'GRASS',        '🌱', 'memes', 3),
  ('npc',          'NPC',          '🤖', 'memes', 4),
  ('lag',          'LAG',          '🐌', 'memes', 5),
  ('cool',         'Cool',         '😎', 'memes', 6),
  ('nerd',         'Nerd',         '🤓', 'memes', 7),
  ('devil',        'Devil',        '😈', 'memes', 8),
  ('frog',         'Frog',         '🐸', 'memes', 9),
  ('robot',        'Robot',        '🤖', 'memes', 10),
  ('slay',         'Slay',         '💅', 'memes', 11),
  ('monke',        'Monke',        '🦍', 'memes', 12),
  ('cap',          'Cap',          '🧢', 'memes', 13),
  ('spill',        'Spill',        '🫗', 'memes', 14),
  ('vanish',       'Vanish',       '😶‍🌫️', 'memes', 15);

-- ========================
-- SOCIAL (10)
-- ========================
INSERT INTO public.reaction_types (slug, display_name, emoji, category, sort_order) VALUES
  ('thumbs_up',    'Thumbs Up',    '👍', 'social', 1),
  ('red_heart',    'Heart',        '❤️', 'social', 2),
  ('blue_heart',   'Blue Heart',   '💙', 'social', 3),
  ('green_heart',  'Green Heart',  '💚', 'social', 4),
  ('purple_heart', 'Purple Heart', '💜', 'social', 5),
  ('handshake',    'Handshake',    '🤝', 'social', 6),
  ('question',     'Question',     '❓', 'social', 7),
  ('speech',       'Speech',       '💬', 'social', 8),
  ('pin',          'Pin',          '📌', 'social', 9),
  ('bell',         'Bell',         '🔔', 'social', 10);
