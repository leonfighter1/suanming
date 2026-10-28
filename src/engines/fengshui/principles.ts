/**
 * 风水 (tech plan WP6.3, the owner's Phase 3 spec): general principles of direction and space for a room,
 * never a 吉凶 judgement of a home. Each principle has its everyday reason (light, air, sleep, safety,
 * privacy, how people move) and, where there is one, the traditional idea behind it, said without 吉凶.
 * Every one is a simplified_rule. Only 风水 reads this table (rule 8): it shares nothing with 一生运势's
 * 八宅, which assigns 吉凶 directions.
 *
 * 繁體 and English are written by hand; so is 简体, in mainland wording (屏幕, 柜子) and quotes (“”), and
 * test/fengshui.test.ts holds it to OpenCC's conversion apart from those. The server never loads OpenCC.
 */

export type Text3 = { "zh-Hant": string; "zh-Hans": string; en: string };

export const AREAS = [
  "bed",
  "desk",
  "seat",
  "door",
  "mirror",
  "light",
  "air",
  "flow",
  "storage",
  "stove",
  "table",
  "safety",
  "colour",
] as const;
export type Area = (typeof AREAS)[number];

export interface Principle {
  id: string;
  area: Area;
  text: Text3;
  why: Text3;
}

const p = (
  id: string,
  area: Area,
  text: [hant: string, hans: string, en: string],
  why: [hant: string, hans: string, en: string],
): Principle => ({
  id,
  area,
  text: { "zh-Hant": text[0], "zh-Hans": text[1], en: text[2] },
  why: { "zh-Hant": why[0], "zh-Hans": why[1], en: why[2] },
});

export const ROOM_IDS = [
  "bedroom",
  "study",
  "living",
  "kitchen",
  "entrance",
  "dining",
  "kids",
] as const;
export type RoomId = (typeof ROOM_IDS)[number];

export const ROOMS: Record<RoomId, { name: Text3; principles: Principle[] }> = {
  bedroom: {
    name: { "zh-Hant": "臥室", "zh-Hans": "卧室", en: "Bedroom" },
    principles: [
      p(
        "bed_wall",
        "bed",
        ["床頭靠實牆。", "床头靠实墙。", "Put the head of the bed against a solid wall."],
        [
          "背後有牆，睡時較有安定感，也少受窗邊冷風與光線干擾；傳統上稱為「背後有靠」。",
          "背后有墙，睡时较有安定感，也少受窗边冷风与光线干扰；传统上称为“背后有靠”。",
          "A wall behind you feels settled and keeps window draughts and light off your head; tradition calls this having support behind you.",
        ],
      ),
      p(
        "bed_door",
        "door",
        [
          "床不正對房門，躺下時能看見門口。",
          "床不正对房门，躺下时能看见门口。",
          "Keep the bed out of line with the door, but where you can see the door when lying down.",
        ],
        [
          "門口的光線、聲音與走動不直衝床上，睡得較安穩；看得見門口也讓人放心。",
          "门口的光线、声音与走动不直冲床上，睡得较安稳；看得见门口也让人放心。",
          "Light, noise and footsteps from the doorway don't run straight at the bed, and seeing the door puts the mind at rest.",
        ],
      ),
      p(
        "bed_mirror",
        "mirror",
        ["鏡子不正對床。", "镜子不正对床。", "Don't let a mirror face the bed."],
        [
          "夜裡醒來時，鏡中的影像和反光容易讓人一驚，也可能影響入睡；可以移開，或睡前用布遮上。",
          "夜里醒来时，镜中的影像和反光容易让人一惊，也可能影响入睡；可以移开，或睡前用布遮上。",
          "A reflection or a glint at night can startle you awake or keep you from sleep; move the mirror, or cover it at bedtime.",
        ],
      ),
      p(
        "bed_overhead",
        "bed",
        [
          "床的上方不放沉重的櫃子或吊飾，也避開橫樑。",
          "床的上方不放沉重的柜子或吊饰，也避开横梁。",
          "Keep heavy shelves and hanging things off the wall above the bed, and don't sleep under a beam.",
        ],
        [
          "頭頂有重物或橫樑會帶來壓迫感，萬一掉落也危險。",
          "头顶有重物或横梁会带来压迫感，万一掉落也危险。",
          "Weight overhead feels oppressive, and anything that falls is a danger.",
        ],
      ),
      p(
        "bed_clear",
        "storage",
        [
          "床底與床邊保持整潔通風。",
          "床底与床边保持整洁通风。",
          "Keep under and around the bed clear and airy.",
        ],
        [
          "少堆雜物，灰塵少、空氣流通，房間也顯得輕鬆。",
          "少堆杂物，灰尘少、空气流通，房间也显得轻松。",
          "Less clutter means less dust and better air, and the room feels lighter.",
        ],
      ),
      p(
        "bed_light",
        "light",
        [
          "臥室用柔和、可調暗的燈光，色調安靜。",
          "卧室用柔和、可调暗的灯光，色调安静。",
          "Use soft, dimmable light and calm colours in the bedroom.",
        ],
        [
          "睡前把光線放柔，身體較容易進入休息狀態。",
          "睡前把光线放柔，身体较容易进入休息状态。",
          "Softer light before sleep helps the body wind down.",
        ],
      ),
    ],
  },
  study: {
    name: { "zh-Hant": "書房 · 工作桌", "zh-Hans": "书房 · 工作桌", en: "Study or desk" },
    principles: [
      p(
        "desk_wall",
        "desk",
        [
          "書桌宜背靠實牆，背後不要是走道或窗。",
          "书桌宜背靠实墙，背后不要是走道或窗。",
          "Sit with a solid wall behind your desk, not a walkway or a window.",
        ],
        [
          "背後有靠，專心時不會被身後的走動或光線打擾；傳統上稱為「背後有靠」。",
          "背后有靠，专心时不会被身后的走动或光线打扰；传统上称为“背后有靠”。",
          "With support behind you, footsteps and glare behind you don't break your focus; tradition calls this having support behind you.",
        ],
      ),
      p(
        "desk_door",
        "door",
        [
          "坐著能看見門口，但不正對門。",
          "坐着能看见门口，但不正对门。",
          "Sit where you can see the door, but not directly facing it.",
        ],
        [
          "看得到誰進來，心裡較踏實；不正對門，就不會被進出的人直接打斷。",
          "看得到谁进来，心里较踏实；不正对门，就不会被进出的人直接打断。",
          "Seeing who comes in is reassuring; not facing the door straight on keeps comings and goings from interrupting you.",
        ],
      ),
      p(
        "desk_light",
        "light",
        [
          "光線從側面來，避免窗戶在螢幕正後方或正前方。",
          "光线从侧面来，避免窗户在屏幕正后方或正前方。",
          "Let light come from the side; avoid a window right behind or right in front of the screen.",
        ],
        [
          "側光不刺眼，螢幕上也少反光，眼睛較不累。",
          "侧光不刺眼，屏幕上也少反光，眼睛较不累。",
          "Side light doesn't glare and puts fewer reflections on the screen, so the eyes tire less.",
        ],
      ),
      p(
        "desk_tidy",
        "storage",
        [
          "桌面只放正在用的東西，常用物品放在順手的位置。",
          "桌面只放正在用的东西，常用物品放在顺手的位置。",
          "Keep only what you're using on the desk, and everyday things within easy reach.",
        ],
        [
          "桌面清爽，開始做事時就少一道整理的阻力。",
          "桌面清爽，开始做事时就少一道整理的阻力。",
          "A clear desk removes one hurdle before you start.",
        ],
      ),
      p(
        "desk_corner",
        "seat",
        [
          "座位避免被尖角或柱角正對。",
          "座位避免被尖角或柱角正对。",
          "Don't let a sharp corner or the edge of a pillar point at your seat.",
        ],
        [
          "尖角對著人會讓人下意識不自在，也容易碰撞；可以移動座位，或用植物、布簾柔化。",
          "尖角对着人会让人下意识不自在，也容易碰撞；可以移动座位，或用植物、布帘柔化。",
          "A corner aimed at you feels uneasy without your noticing, and it's easy to bump; move the seat, or soften the corner with a plant or a curtain.",
        ],
      ),
    ],
  },
  living: {
    name: { "zh-Hant": "客廳", "zh-Hans": "客厅", en: "Living room" },
    principles: [
      p(
        "sofa_wall",
        "seat",
        [
          "沙發背後靠牆，坐著能看見入口。",
          "沙发背后靠墙，坐着能看见入口。",
          "Put the sofa's back to a wall, where you can see the way in.",
        ],
        [
          "背後有靠、看得見入口，坐著較放鬆。",
          "背后有靠、看得见入口，坐着较放松。",
          "Support behind and a view of the entrance make it easier to relax.",
        ],
      ),
      p(
        "living_flow",
        "flow",
        [
          "走道保持通暢，家具不擋住門和窗。",
          "走道保持通畅，家具不挡住门和窗。",
          "Keep walkways open, and don't block doors and windows with furniture.",
        ],
        [
          "走動順手，空氣與光線也能進來；傳統上把這叫做讓「氣」流通。",
          "走动顺手，空气与光线也能进来；传统上把这叫做让“气”流通。",
          "Moving around is easy, and light and air can come in; tradition calls this letting the qi flow.",
        ],
      ),
      p(
        "living_light",
        "light",
        [
          "白天多用自然光，晚上光線溫暖均勻，不留陰暗的角落。",
          "白天多用自然光，晚上光线温暖均匀，不留阴暗的角落。",
          "Use daylight in the day and warm, even light at night, with no dark corners.",
        ],
        [
          "明亮均勻的空間讓人精神好，也比較安全。",
          "明亮均匀的空间让人精神好，也比较安全。",
          "An evenly lit room keeps you alert, and it is safer.",
        ],
      ),
      p(
        "living_plants",
        "air",
        [
          "放一兩盆容易照顧的植物。",
          "放一两盆容易照顾的植物。",
          "Keep one or two easy-care plants.",
        ],
        [
          "植物讓空間有生氣，照顧它們也是一種放鬆。",
          "植物让空间有生气，照顾它们也是一种放松。",
          "Plants bring the room to life, and tending them is a way to unwind.",
        ],
      ),
      p(
        "living_through",
        "flow",
        [
          "大門若一眼直通窗戶或陽台，可以用屏風、櫃子或植物稍作遮擋。",
          "大门若一眼直通窗户或阳台，可以用屏风、柜子或植物稍作遮挡。",
          "If the front door looks straight through to a window or balcony, partly screen the line with a screen, a cabinet or plants.",
        ],
        [
          "進門時不會一眼看穿整個家，多一分隱私；傳統上認為這樣「氣」不會直進直出。",
          "进门时不会一眼看穿整个家，多一分隐私；传统上认为这样“气”不会直进直出。",
          "The home isn't seen through at a glance, which adds privacy; tradition holds that the qi then doesn't rush straight in and out.",
        ],
      ),
    ],
  },
  kitchen: {
    name: { "zh-Hant": "廚房", "zh-Hans": "厨房", en: "Kitchen" },
    principles: [
      p(
        "stove_sink",
        "stove",
        [
          "爐灶與水槽不正對，也不緊貼。",
          "炉灶与水槽不正对，也不紧贴。",
          "Don't put the stove directly opposite the sink or right against it.",
        ],
        [
          "兩者之間留出工作檯，備料與烹調都順手，也較安全；傳統上講究把水與火分開。",
          "两者之间留出工作台，备料与烹调都顺手，也较安全；传统上讲究把水与火分开。",
          "A worktop between them makes prep and cooking easier and safer; tradition keeps water and fire apart.",
        ],
      ),
      p(
        "stove_wall",
        "stove",
        [
          "爐灶背後是實牆，不在窗下。",
          "炉灶背后是实墙，不在窗下。",
          "Back the stove onto a solid wall, not under a window.",
        ],
        [
          "窗邊的風會吹動火焰，窗簾也可能靠近火源。",
          "窗边的风会吹动火焰，窗帘也可能靠近火源。",
          "A draught from the window moves the flame, and a curtain may come near it.",
        ],
      ),
      p(
        "kitchen_air",
        "air",
        [
          "保持通風與整潔，刀具收好。",
          "保持通风与整洁，刀具收好。",
          "Keep the kitchen aired and tidy, and put knives away.",
        ],
        [
          "油煙散得快，空氣清新；刀具收好也更安全。",
          "油烟散得快，空气清新；刀具收好也更安全。",
          "Cooking fumes clear quickly, and stored knives are safer.",
        ],
      ),
      p(
        "kitchen_light",
        "light",
        ["工作檯上方要有足夠的燈光。", "工作台上方要有足够的灯光。", "Light the worktop well."],
        [
          "切菜和烹調時看得清楚，比較安全。",
          "切菜和烹调时看得清楚，比较安全。",
          "Seeing clearly while cutting and cooking is safer.",
        ],
      ),
    ],
  },
  entrance: {
    name: { "zh-Hant": "玄關", "zh-Hans": "玄关", en: "Entrance" },
    principles: [
      p(
        "entry_bright",
        "light",
        ["玄關保持明亮、整潔。", "玄关保持明亮、整洁。", "Keep the entrance bright and tidy."],
        [
          "回家第一眼清爽明亮，心情也跟著放鬆；傳統上把入口看作一家的「氣口」。",
          "回家第一眼清爽明亮，心情也跟着放松；传统上把入口看作一家的“气口”。",
          "A clear, bright first sight on coming home helps you unwind; tradition sees the entrance as the home's mouth of qi.",
        ],
      ),
      p(
        "entry_shoes",
        "storage",
        [
          "鞋子收進鞋櫃，門口不堆雜物。",
          "鞋子收进鞋柜，门口不堆杂物。",
          "Put shoes away in a cabinet, and keep the doorway clear.",
        ],
        [
          "進出順暢，也少絆倒的危險。",
          "进出顺畅，也少绊倒的危险。",
          "Coming and going is easy, with less to trip over.",
        ],
      ),
      p(
        "entry_mirror",
        "mirror",
        [
          "鏡子不正對大門，可以放在側牆。",
          "镜子不正对大门，可以放在侧墙。",
          "Don't hang a mirror facing the front door; put it on a side wall.",
        ],
        [
          "一開門就看見自己的影像容易嚇一跳；側牆上的鏡子出門前一樣能整理儀容。",
          "一开门就看见自己的影像容易吓一跳；侧墙上的镜子出门前一样能整理仪容。",
          "Seeing your reflection as the door opens can startle you; a mirror on a side wall still lets you check yourself before going out.",
        ],
      ),
      p(
        "entry_screen",
        "flow",
        [
          "入門處若能直接看見全屋，可以用屏風或櫃子隔出一點玄關。",
          "入门处若能直接看见全屋，可以用屏风或柜子隔出一点玄关。",
          "If the whole home is visible from the door, set off a small entry with a screen or a cabinet.",
        ],
        [
          "多一層隱私，進門也有個轉換心情的地方。",
          "多一层隐私，进门也有个转换心情的地方。",
          "It adds privacy, and a place to change pace on arriving.",
        ],
      ),
    ],
  },
  dining: {
    name: { "zh-Hant": "餐廳", "zh-Hans": "餐厅", en: "Dining room" },
    principles: [
      p(
        "table_door",
        "table",
        [
          "餐桌不正對大門或廁所門。",
          "餐桌不正对大门或厕所门。",
          "Keep the dining table out of line with the front door and the toilet door.",
        ],
        [
          "用餐時少受進出與氣味打擾，坐得安穩。",
          "用餐时少受进出与气味打扰，坐得安稳。",
          "Meals are less disturbed by comings and goings and by smells.",
        ],
      ),
      p(
        "table_light",
        "light",
        [
          "餐桌上方用溫暖的燈光，桌面保持清爽。",
          "餐桌上方用温暖的灯光，桌面保持清爽。",
          "Light the table warmly, and keep it clear.",
        ],
        [
          "溫暖的光讓人願意坐下來好好吃飯、聊天。",
          "温暖的光让人愿意坐下来好好吃饭、聊天。",
          "Warm light invites people to sit, eat and talk.",
        ],
      ),
      p(
        "table_space",
        "flow",
        [
          "餐椅後方留出走動的空間。",
          "餐椅后方留出走动的空间。",
          "Leave room to walk behind the dining chairs.",
        ],
        [
          "起身、上菜都方便，不會擠來擠去。",
          "起身、上菜都方便，不会挤来挤去。",
          "Getting up and serving are easy, without squeezing past.",
        ],
      ),
    ],
  },
  kids: {
    name: { "zh-Hant": "兒童房", "zh-Hans": "儿童房", en: "Children's room" },
    principles: [
      p(
        "kids_bed",
        "bed",
        [
          "床頭靠實牆，床不正對房門。",
          "床头靠实墙，床不正对房门。",
          "Put the head of the bed against a solid wall, out of line with the door.",
        ],
        [
          "孩子睡得較有安全感，也少受門外的光線和聲音打擾。",
          "孩子睡得较有安全感，也少受门外的光线和声音打扰。",
          "Children feel safer asleep, and are less disturbed by light and noise from outside.",
        ],
      ),
      p(
        "kids_desk",
        "desk",
        [
          "書桌背後有靠，光線從側面來。",
          "书桌背后有靠，光线从侧面来。",
          "Give the desk a wall behind it and light from the side.",
        ],
        [
          "寫作業時較能專心，眼睛也不容易累。",
          "写作业时较能专心，眼睛也不容易累。",
          "Homework is easier to focus on, and the eyes tire less.",
        ],
      ),
      p(
        "kids_safe",
        "safety",
        [
          "家具的尖角加上防撞套，重物不放在高處。",
          "家具的尖角加上防撞套，重物不放在高处。",
          "Cover sharp furniture corners, and keep heavy things off high shelves.",
        ],
        [
          "孩子活潑好動，安全最重要。",
          "孩子活泼好动，安全最重要。",
          "Children are lively: safety comes first.",
        ],
      ),
      p(
        "kids_colour",
        "colour",
        [
          "色彩明亮柔和，收納放在孩子拿得到的高度。",
          "色彩明亮柔和，收纳放在孩子拿得到的高度。",
          "Use bright, soft colours, and storage at a height the child can reach.",
        ],
        [
          "柔和的顏色讓人安定；孩子能自己收拾，也是一種學習。",
          "柔和的颜色让人安定；孩子能自己收拾，也是一种学习。",
          "Soft colours are calming, and tidying up by themselves is part of learning.",
        ],
      ),
    ],
  },
};

export const FACINGS = [
  "north",
  "northeast",
  "east",
  "southeast",
  "south",
  "southwest",
  "west",
  "northwest",
] as const;
export type Facing = (typeof FACINGS)[number];

/** 後天八卦方位: each direction's trigram and 五行, the traditional association a facing carries. */
export const DIRECTIONS: Record<Facing, { name: Text3; trigram: Text3; element: Text3 }> = {
  north: {
    name: { "zh-Hant": "北", "zh-Hans": "北", en: "North" },
    trigram: { "zh-Hant": "坎", "zh-Hans": "坎", en: "Kan" },
    element: { "zh-Hant": "水", "zh-Hans": "水", en: "Water" },
  },
  northeast: {
    name: { "zh-Hant": "東北", "zh-Hans": "东北", en: "Northeast" },
    trigram: { "zh-Hant": "艮", "zh-Hans": "艮", en: "Gen" },
    element: { "zh-Hant": "土", "zh-Hans": "土", en: "Earth" },
  },
  east: {
    name: { "zh-Hant": "東", "zh-Hans": "东", en: "East" },
    trigram: { "zh-Hant": "震", "zh-Hans": "震", en: "Zhen" },
    element: { "zh-Hant": "木", "zh-Hans": "木", en: "Wood" },
  },
  southeast: {
    name: { "zh-Hant": "東南", "zh-Hans": "东南", en: "Southeast" },
    trigram: { "zh-Hant": "巽", "zh-Hans": "巽", en: "Xun" },
    element: { "zh-Hant": "木", "zh-Hans": "木", en: "Wood" },
  },
  south: {
    name: { "zh-Hant": "南", "zh-Hans": "南", en: "South" },
    trigram: { "zh-Hant": "離", "zh-Hans": "离", en: "Li" },
    element: { "zh-Hant": "火", "zh-Hans": "火", en: "Fire" },
  },
  southwest: {
    name: { "zh-Hant": "西南", "zh-Hans": "西南", en: "Southwest" },
    trigram: { "zh-Hant": "坤", "zh-Hans": "坤", en: "Kun" },
    element: { "zh-Hant": "土", "zh-Hans": "土", en: "Earth" },
  },
  west: {
    name: { "zh-Hant": "西", "zh-Hans": "西", en: "West" },
    trigram: { "zh-Hant": "兌", "zh-Hans": "兑", en: "Dui" },
    element: { "zh-Hant": "金", "zh-Hans": "金", en: "Metal" },
  },
  northwest: {
    name: { "zh-Hant": "西北", "zh-Hans": "西北", en: "Northwest" },
    trigram: { "zh-Hant": "乾", "zh-Hans": "乾", en: "Qian" },
    element: { "zh-Hant": "金", "zh-Hans": "金", en: "Metal" },
  },
};
