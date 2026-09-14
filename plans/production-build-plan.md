# StealAnEggs: Production Build Plan

สถานะ: กำลังดำเนินงาน — automated M0 gate ผ่านแล้ว และ M1 graybox source ถูกเพิ่มแล้ว
ขอบเขต: เกม Roblox ต้นฉบับแบบ single-place MVP; ไม่คัดลอก map, assets, scripts, ชื่อเฉพาะ หรือตัวละครจากเกม/อนิเมะอื่น

## 1. เป้าหมายการส่งมอบ

สร้าง experience ที่ผู้เล่น 2–8 คนสามารถ:

1. เข้าเกมและรับฐานอย่างถูกต้อง
2. ฝึกลู่วิ่งเพื่อเพิ่มความเร็วภายใต้เพดานที่กำหนด
3. เก็บหรือขโมยไข่จากผู้เล่นอื่น
4. นำไข่กลับฐานแล้วฟักเป็น creature ต้นฉบับ
5. รับรายได้ passive จาก creature และใช้ Coins อัปเกรด
6. ออกจากเกมแล้วกลับมาโดยข้อมูลไม่สูญหายหรือถูกทำซ้ำ
7. เล่นได้บน desktop, mobile และ gamepad

MVP ถือว่าเสร็จเมื่อ private beta เล่นครบลูปต่อเนื่อง 20 นาทีด้วย 4 clients โดยไม่มี error ใน Output, ไม่มีการเพิ่มเงินจาก client และไม่มีข้อมูลสูญหายหลัง reconnect.

## 2. สถานะปัจจุบัน

มีแล้ว:

- Rojo manifest: `default.project.json`
- server-authoritative pickup/steal/drop/deposit
- egg rarity: Common, Rare, Legendary
- treadmill, Speed, Coins
- hatch และ `PetInventory`
- passive income และ Lumina mutation event
- anti-spam และ movement plausibility บางส่วน
- TestService contract tests สำหรับ catalogs และ map structure

ช่องว่างก่อนเป็นเกมจริง:

- มี M1 graybox map source และ build เป็น place ได้แล้ว แต่ยังต้องตรวจใน Roblox Studio
- `EggServer.server.luau` รวมหลายระบบในไฟล์เดียว
- Coins, eggs, pets, speed และ mutation ยังไม่ persist
- UI ยังเป็น prototype และยังไม่รองรับ mobile/gamepad อย่างครบถ้วน
- ไม่มี base ownership, upgrades, onboarding, analytics หรือ production QA
- ติดตั้ง toolchain แบบ pin แล้ว: Rojo 7.7.0, StyLua 2.5.2 และ Selene 0.31.0
- repository ยังไม่มี commit แรกและไม่มี remote

## 3. สถาปัตยกรรมเป้าหมาย

```text
StealAnEggs/
├─ src/
│  ├─ ReplicatedStorage/StealAnEggs/
│  ├─ Shared/
│  │  ├─ Config.luau
│  │  ├─ EggCatalog.luau
│  │  ├─ CreatureCatalog.luau
│  │  └─ NetworkTypes.luau
│  └─ Remotes/                 # สร้าง/ตรวจโดย ServerInit
│  ├─ ServerScriptService/
│  ├─ ServerInit.server.luau
│  └─ Services/
│     ├─ DataService.luau
│     ├─ PlayerStateService.luau
│     ├─ BaseService.luau
│     ├─ EggService.luau
│     ├─ StealService.luau
│     ├─ TreadmillService.luau
│     ├─ CreatureService.luau
│     ├─ EconomyService.luau
│     └─ EventService.luau
│  └─ StarterPlayer/StarterPlayerScripts/
│  ├─ ClientInit.client.luau
│  └─ Controllers/
│     ├─ HUDController.luau
│     ├─ InputController.luau
│     └─ FeedbackController.luau
├─ map/
│  └─ World.project.json       # mount เป็น Workspace.GameMap
└─ tests/
   ├─ unit/
   ├─ integration/
   └─ studio/
```

หลักคงที่ทุก milestone:

- Client ส่ง intent เท่านั้น; server เลือกผลลัพธ์ รางวัล rarity mutation และตำแหน่ง
- replicated catalog ใช้เพื่อ display ได้ แต่ห้ามใช้ replicated value เป็นสิทธิ์หรือ source of truth
- Remotes ต้อง validate type, state, distance, cooldown และ ownership
- DataStore ใช้ server เท่านั้น; load ไม่สำเร็จต้องไม่ save default ทับข้อมูลจริง
- ไม่มี secrets หรือ content ที่ยังไม่พร้อมเปิดเผยใน replicated containers

## 4. แบบแปลน map MVP

ใช้ Parts ต้นฉบับก่อนนำ art assets เข้า เพื่อให้ทดสอบ gameplay ได้เร็ว:

```text
ขอบเขต map เริ่มต้นประมาณ 450 x 450 studs

┌───────────────┬────────────────────┬───────────────┐
│ Bases A/B     │ North routes       │ Bases C/D     │
│ Deposit/Hatch │ obstacles + cover  │ Deposit/Hatch │
├───────────────┼────────────────────┼───────────────┤
│ West route    │ Central Egg Arena  │ East route    │
│ 2 approaches  │ 6 spawn points     │ 2 approaches  │
├───────────────┼────────────────────┼───────────────┤
│ Bases E/F     │ Safe training hub  │ Bases G/H     │
│ Deposit/Hatch │ 4 treadmills       │ Deposit/Hatch │
└───────────────┴────────────────────┴───────────────┘
```

ข้อกำหนด blockout:

- มี 8 ฐานสำหรับผู้เล่นสูงสุด 8 คน; แต่ละฐานมี `SpawnLocation`, `DepositZone`, `HatchZone`, ป้ายเจ้าของ และ barrier ที่ไม่ขวางทางถาวร
- จาก Central Arena ไปแต่ละฐานมีอย่างน้อย 2 เส้นทางและ line-of-sight break
- จุดไข่ไม่อยู่ติดฐาน; เวลาเดินปกติจากไข่ถึงฐานควรเปิดโอกาสให้ขโมย
- Treadmills อยู่ safe zone แต่รายได้/ความเร็วมี cap
- ไม่มี kill pits ที่ทำให้ผู้เล่นใหม่สูญเสียไข่โดยไม่เข้าใจกติกา
- ทุก gameplay Part anchored และตั้ง collision group อย่างชัดเจน

## 5. Dependency graph

```text
M0 Tooling + baseline
 ├─> M1 Map blockout
 └─> M2 Service refactor
       └─> M3 Versioned persistence
M1 + M2 + M3 ─> M4 Base/core-loop integration
M4 ─> M5 Economy/upgrades
M4 ──────> M6 Production UI/onboarding
M3 + M5 + M6 ─> M7 QA/security/performance
M7 ─> M8 Private beta/publish
M8 ─> M9 LiveOps
```

M1 และ M2 ทำคู่ขนานได้หลัง M0. M5 และ M6 ทำคู่ขนานได้หลัง data contracts และ core-loop API คงที่.

## 6. Milestones

### M0 — Tooling และ baseline ที่ทำซ้ำได้

Progress (2026-09-07): automated gate ผ่านแล้ว (`make verify`), สร้าง place สำเร็จ และเปิดใน Roblox Studio ได้ โดย TestService specs ทั้งสามผ่าน. แก้ startup error จากการสร้าง DataStore ทั้งที่ persistence ปิดแล้ว. งานที่ยังเหลือคือเชื่อม Rojo plugin กับ private development place. Initial commit และ remote ยังไม่ทำเพราะผู้ใช้ยังไม่ได้สั่ง.

Context: โปรเจกต์มี `default.project.json` แต่ยังตรวจ build ด้วย Rojo ไม่ได้และยังไม่มี commit.

งาน:

- ติดตั้ง Roblox Studio, Rojo CLI และ Rojo Studio plugin จากแหล่งทางการ
- เพิ่ม `.gitignore` และเลือก `rokit.toml` หรือเครื่องมือ pin เวอร์ชันเพียงชนิดเดียว พร้อมล็อก Rojo, StyLua และ Selene เป็นเวอร์ชันแน่นอน
- แก้ `default.project.json` ให้ map, shared modules, services, controllers และ tests ถูก map ครบ
- เพิ่ม `servePlaceIds` หลังสร้าง private test place เพื่อป้องกัน sync ผิด experience
- สร้างคำสั่งมาตรฐาน: build, static check, test และ format
- บันทึก baseline ด้วย initial commit หลังตรวจ diff; ยังไม่ push จนผู้ใช้อนุมัติ

Verification:

```bash
rojo build default.project.json -o build/StealAnEggs.rbxlx
stylua --check src tests
selene src tests
git diff --check
```

Studio-only gate: เปิดไฟล์ build แล้วรัน TestService catalog specs. Gameplay startup gate ยังไม่บังคับใน M0 เพราะ map contract จะเกิดใน M1.

Exit criteria: Rojo build สำเร็จ, Studio เปิดไฟล์ได้, scripts อยู่ตำแหน่งถูกต้อง, format/lint ผ่าน และ catalog specs ผ่าน. เกณฑ์ “ไม่มี gameplay startup error” เริ่มบังคับหลัง M1+M2 integration.

Rollback: คืนเฉพาะ tooling/config commit; ไม่กระทบ gameplay logic.

### M1 — สร้าง map blockout ที่ version-control ได้

Progress (2026-09-07): เพิ่ม `map/World.project.json` ซึ่ง build เป็น `Workspace.GameMap` พร้อม 8 bases, 6 egg spawns, 8 deposit zones, 4 treadmills, central arena, cover และ boundaries แล้ว รวมทั้งเพิ่ม `MapContractSpec` และ `MapTravelTimeSpec`. Automated build/lint/format ผ่าน; Studio map contract และ visual load ผ่าน. `MapTravelTimeSpec` คุมค่า geometry estimate ของฐาน→ไข่, ฐาน→ศูนย์กลาง และฐาน→ฐานข้างเคียงเท่านั้น; travel ผ่านทางเดินจริงและ multiplayer gates ยังรอตรวจ.

Context: ระบบปัจจุบันคาดหวัง `EggSpawnPoints`, `EggDepositZones`, `Treadmills` แต่ repo ไม่มี Instances เหล่านี้.

งาน:

- สร้าง Baseplate, boundaries, central arena, 8 bases, 6 egg spawns และ 4 treadmill zones
- mount `map/World.project.json` เป็น `Workspace.GameMap`; ภายในมี `EggSpawnPoints`, `EggDepositZones`, `Treadmills` และ `PlayerBases`
- M2 ต้องย้าย runtime discovery จาก root-level Workspace folders ไป contract นี้โดยใช้ tags/attributes; ระหว่างนั้น M1 ตรวจเฉพาะ geometry และ validator ไม่อ้างว่าระบบเดิมเล่นได้
- เพิ่ม `MapValidator` สำหรับตรวจจำนวน spawn/base/zone, Anchored, duplicate names และ missing tags ตอน Studio test
- ทำ graybox ด้วยสีเรียบก่อน; ยังไม่ใช้ Toolbox free models ที่มี scripts
- คุม geometry estimate ของ base ↔ center และ base ↔ base ที่ `BASE_WALK_SPEED` เริ่มต้น 16; ยืนยันเวลาเดินจริงที่ speed ต่ำสุด/สูงสุดด้วย manual playtest ก่อนปิด M1

Verification:

- F5 solo: spawn ไม่ตก map, ไข่เกิดครบ, deposit และ treadmill ทำงาน
- validator พบฐานและ spawn ครบ 8 ชุด โดย `BaseId` ไม่ซ้ำ; การแจกฐานให้ผู้เล่นทดสอบใน M4
- ไม่มีเส้นทางที่ติดหรือจุดที่ไข่ตกออกนอก playable area

Exit criteria: geometry, tags, attributes และ travel-time targets ผ่าน validator; หลังรวม M2 แล้ว gameplay เริ่มได้โดยไม่สร้าง object ด้วยมือและไม่มี startup error.

Rollback: map อยู่ใน commit แยกจาก services.

### M2 — แยก monolith เป็น Services/Controllers

Progress (2026-09-07): เริ่มแยก bootstrap boundary แล้วด้วย `Services/RemoteRegistry.luau` และ `RemoteRegistrySpec`. `EggServer` ใช้ registry เดียวกันสำหรับ `RequestDrop`, `RequestHatch` และ `Feedback`; remote ที่มีชื่อซ้ำแต่ class ผิดจะ fail closed แทนการถูกแทนที่เงียบ ๆ. ยังไม่ได้ย้าย gameplay state หรือ controllers ออกจาก monolith.

Context: `EggServer.server.luau` ยาวกว่า 500 บรรทัดและดูแล remotes, state, movement, economy, data และ events พร้อมกัน.

งาน:

- เขียน characterization tests ก่อนย้าย logic
- สร้าง `ServerInit` และ dependency injection แบบ table ธรรมดา
- แยก `EggService`, `StealService`, `TreadmillService`, `CreatureService`, `EconomyService`, `EventService`
- แยก UI/input/feedback ออกจาก `EggClient` เป็น controllers
- ทำ remote registry กลาง; reject Remote ชื่อซ้ำหรือ class ผิด
- ให้ services มี `init()` และ `start()` เพื่อไม่ให้ require แล้วเกิด side effect

Verification:

- tests เดิมผ่าน
- client ยังมีเพียง drop/hatch intents
- flow pickup → steal → deposit → hatch → passive income เหมือนเดิม

Exit criteria: bootstrap ไม่มี business logic; service แต่ละไฟล์มีหน้าที่เดียวและมี unit-test surface.

Rollback: ทำเป็น mechanical refactor commit โดยไม่เปลี่ยน balance.

### M3 — Versioned persistence ที่ปลอดภัย

Context: ตอนนี้ save เฉพาะ Score; Coins, Speed, eggs, creatures และ mutations หายเมื่อ reconnect.

Schema v1:

```luau
{
  schemaVersion = 1,
  revision = 0,
  score = 0,
  coins = 0,
  speed = 16,
  eggInventory = { Common = 0, Rare = 0, Legendary = 0 },
  creatures = {
    { id = "server-generated-id", species = "Chick", mutation = "None" }
  },
  upgrades = { treadmill = 0, storage = 0 },
}
```

งาน:

- สร้าง `DataService` พร้อม default factory, validation, migration และ per-player save lock
- ใช้ `UpdateAsync`; callback ห้าม yield
- track dirty/revision และ retry ด้วย bounded exponential backoff
- ใช้ profile/session ownership lock ข้าม server พร้อม lease expiry/renewal; ถ้าเสีย lock ให้หยุด economy mutations และนำผู้เล่นออกอย่างปลอดภัย
- ทำ revision compare ภายใน `UpdateAsync` เพื่อปฏิเสธ stale full-profile writes
- hatch, purchase และ grant สำคัญต้องมี idempotency/action ID เพื่อ replay แล้วไม่แจกซ้ำ
- autosave แบบกระจายเวลา ไม่ยิงผู้เล่นทั้งหมดพร้อมกัน
- เมื่อ load fail ให้ปิด economy actions ของผู้เล่นและแสดง retry state; ห้าม save default
- จำกัดจำนวน creatures/inventory และขนาด payload
- ใช้ datastore แยกสำหรับ development/private test และ production

Verification:

- unit tests: malformed data, old schema, duplicate save, save fail, load fail
- Studio private test: earn → leave → rejoin → state ตรงเดิม
- shutdown test: `BindToClose` ไม่เขียน delta ซ้ำ
- two-server simulation: profile เดียวเปิดซ้อนไม่ได้, stale server เขียนทับไม่ได้ และ lock หมดอายุมี recovery path

Exit criteria: reconnect 20 รอบและ concurrent save tests ไม่มี loss/duplication; error path ไม่ทับข้อมูลเก่า.

Rollback: feature flag ปิด persistence แล้วใช้ session state; ห้าม downgrade schema โดยอัตโนมัติ.

### M4 — Base ownership และ core loop สมบูรณ์

Dependencies: M1, M2 และ M3
Context: deposit zones ปัจจุบันไม่ผูกฐานกับผู้เล่น จึงยังไม่ใช่ PvP base game จริง และการเปลี่ยน ownership ต้องผูกกับ persistence transaction ที่พร้อมก่อน.

งาน:

- `BaseService` จัดสรร/คืนฐานแบบ deterministic และรองรับ join/leave
- deposit/hatch ต้องตรวจว่า zone เป็นฐานของผู้เล่น
- นิยาม state machine: `Spawned → Carried → Stolen → Secured → Hatched`
- เพิ่ม protection หลัง spawn, หลังถูกขโมย และหลังเกิดใหม่ โดยมี UI บอกเวลาชัดเจน
- เพิ่ม respawn/drop recovery และ duplicate-spawn guard ต่อ spawn point
- จำกัด inventory และจัดการ full-inventory อย่างไม่ทำของหาย
- เปลี่ยน pet IDs เป็น GUID ที่ server สร้าง

Verification:

- 4 clients แย่งไข่พร้อมกัน: มี carrier คนเดียว
- ผู้เล่นส่งไข่ที่ฐานคนอื่นไม่ได้
- death/leave/reset ระหว่างทุก state แล้ว egg ไม่ค้างหรือ duplicate
- remote spam และ prompt ระยะไกลไม่เปลี่ยน state

Exit criteria: gameplay loop จบได้ครบและ state invariants ผ่าน stress test.

Rollback: ปิด base ownership feature flag แล้วกลับเป็น shared deposit สำหรับ debug.

### M5 — Economy และ upgrades ที่ balance ได้

Context: มี Coins/Speed/passive income แล้ว แต่ไม่มี sinks หรือ progression limits ที่ครบ.

งาน:

- เพิ่ม upgrade catalog สำหรับ treadmill speed, creature storage และ income bonus
- ใช้ server-side purchase transaction: validate ID → current level → price → balance → apply atomically
- สร้าง spreadsheet/Markdown balance table สำหรับ time-to-first-upgrade และ progression 20 นาทีแรก
- clamp multipliers ทุกชั้น; unknown creature/reward/upgrade ไม่สร้างรางวัล ส่วน unknown mutation ใช้ multiplier กลาง `1x` ตาม contract ปัจจุบัน
- mutation event ใช้โอกาสเริ่ม event แยกจากโอกาสต่อ creature
- monetization หลัง retention loop สนุกแล้วเท่านั้น; หลีกเลี่ยง pay-to-win และ loot outcomes ที่คลุมเครือ

Verification:

- ไม่สามารถซื้อเมื่อ Coins ไม่พอหรือส่งราคาเอง
- reconnect แล้วระดับ upgrade ถูกต้อง
- income ไม่ overflow และ lag spike ไม่จ่ายย้อนหลังเกิน cap

Exit criteria: มีอย่างน้อย 3 meaningful upgrades และผู้เล่นใหม่เห็นความก้าวหน้าใน 5 นาทีแรก.

Rollback: catalog-driven feature flag ต่อ upgrade.

### M6 — UI, onboarding และ accessibility

Context: UI ปัจจุบันสร้างด้วย LocalScript และเป็น fixed offsets.

งาน:

- ย้าย UI เป็น StarterGui assets + controller logic
- HUD: Coins, Speed, carrying state, base, passive income, active event
- inventory/hatch/upgrade panels พร้อม empty/loading/error states
- tutorial 4 ขั้น: train → pickup → return → hatch
- รองรับ touch button, keyboard และ gamepad ผ่าน action binding
- ใช้ responsive constraints, safe areas, readable contrast และไม่พึ่งสีอย่างเดียวบอก rarity
- feedback สำคัญมีทั้งข้อความ, icon และเสียงต้นฉบับ/ได้รับอนุญาต

Verification:

- Device Emulator: phone portrait/landscape, tablet, desktop
- gamepad-only จบ tutorial ได้
- UI ไม่ล้น, ปุ่มสัมผัสไม่ซ้อน และ text localization-ready

Exit criteria: ผู้ทดสอบใหม่ 3 คนจบ core loop โดยไม่ต้องอธิบายด้วยเสียง.

Rollback: เปิด prototype HUD ผ่าน debug flag.

### M7 — QA, security และ performance gate

Context: ก่อน public beta ต้องพิสูจน์ behavior ใน client-server simulation จริง.

Test matrix:

- unit: catalogs, weighted roll, economy, data migration, state transitions
- integration: remotes, base ownership, save/load, join/leave
- multiplayer: F7 ด้วย 2, 4 และ 8 clients
- adversarial: spam, malformed args, teleport, remote replay, prompt/touched spoof candidates
- device: mobile low resolution, desktop, gamepad
- performance: server frame time, instance count, memory, network receive/send

งาน:

- เปิด StreamingEnabled เฉพาะหลังตรวจ gameplay references
- ตั้ง budgets สำหรับ Part/Instance count และ remote frequency
- ตรวจ replicated containers ว่าไม่มี server-only tables/assets
- ตรวจ imported assets ทุกชิ้นและลบ unknown scripts
- originality audit เปรียบเทียบ topology, names, icons, screenshots, thumbnails, audio และ branded phrasing กับ reference; ใช้ได้เฉพาะ mechanics/layout principles ระดับสูง
- ทำ bug severity rubric และ release checklist

Exit criteria:

- 0 critical/high correctness หรือ security bugs
- 0 unhandled errors ใน session 30 นาที / 8 clients
- autosave ไม่มี budget storm
- mobile client รักษา framerate เป้าหมายที่กำหนดบนอุปกรณ์ทดสอบ

Rollback: beta remains private; revert milestone commit rather than hot-patching production data.

### M8 — Private beta และ publish

Context: Roblox experience ใหม่เป็น private โดยค่าเริ่มต้น; ใช้ private test place แยกจาก production data.

งาน:

- สร้าง experience ภายใต้ account/group ที่ผู้ใช้เป็นเจ้าของ
- ตั้งชื่อ/คำอธิบาย/ไอคอน/thumbnail ด้วย assets ต้นฉบับ
- ใช้ชื่อ public ที่แยกชัดจาก `Steal An Egg`; `StealAnEggs` เป็น working repository name เท่านั้น
- สร้าง development place และ production start place
- ตั้ง access เป็น private แล้วเชิญ testers
- ตั้ง policy/compliance, supported devices, localization และ age-appropriate content
- เก็บ metrics: tutorial completion, first hatch, session length, steal success, retention proxies, errors
- แก้ blocker แล้วค่อยพิจารณา public/beta release ตามข้อกำหนด publishing ปัจจุบัน

Exit criteria: private beta 2 รอบ, รอบละอย่างน้อย 5 testers; crash/data-loss/blocker = 0 และ tutorial completion ≥ 80%.

Rollback: เปลี่ยน access กลับ private; data migration ทุกครั้งต้องรองรับ rollback-safe reads.

### M9 — LiveOps หลังเปิดตัว

งานหลัง launch:

- event calendar 4 สัปดาห์และ content cadence ที่ทีมทำไหว
- balance config ที่ versioned และมี staged rollout
- เพิ่ม biome/creatures แบบต้นฉบับทีละชุด
- moderation/reporting และ recovery tooling สำหรับ data incidents
- วิเคราะห์ metrics ก่อนเพิ่ม trading, rebirth, battle pass หรือ developer products

ไม่ใส่ trading ใน MVP เพราะมีความเสี่ยง duplication, scam และ support สูง; ทำหลัง persistence และ audit log แข็งแรงแล้วเท่านั้น.

## 7. ลำดับงานแบบ session/PR

| Step | Deliverable | Dependency | ทำคู่ขนานได้ | ประมาณการ |
|---|---|---|---|---|
| 1 | Toolchain + reproducible build | ไม่มี | ไม่ | 0.5–1 วัน |
| 2 | Graybox map + validator | 1 | กับ Step 3 | 1–2 วัน |
| 3 | Service/controller refactor | 1 | กับ Step 2 | 2–3 วัน |
| 4 | Versioned DataService | 3 | ไม่ | 2–3 วัน |
| 5 | Base ownership + state machine | 2,3,4 | ไม่ | 2–3 วัน |
| 6 | Upgrades/economy balance | 4,5 | กับ Step 7 | 2 วัน |
| 7 | Production UI/tutorial | 3,5 | กับ Step 6 | 2–3 วัน |
| 8 | QA/security/performance | 4–7 | ไม่ | 2–3 วัน |
| 9 | Private beta + fixes | 8 | ไม่ | 1–2 รอบทดสอบ |
| 10 | Public launch gate | 9 | ไม่ | ตามผล beta |

ประมาณการนี้เป็น engineering effort ไม่ใช่วันรับประกัน และยังไม่รวมเวลาสร้าง 3D art/audio คุณภาพ production.

## 8. Definition of Done ต่อการเปลี่ยนแปลง

ทุก step ต้อง:

1. มี tests เขียนก่อน behavior ใหม่และครอบคลุม happy/error/boundary paths
2. ผ่าน build/static checks และ `git diff --check`
3. ผ่าน code review; security-sensitive changes ผ่าน security review
4. ไม่มี hardcoded secrets หรือ client-authoritative reward
5. อัปเดต README/GDD เฉพาะข้อมูลที่เปลี่ยน
6. มี rollback และ migration note ถ้าแตะ persistence
7. ไม่ commit/push/publish เว้นแต่ผู้ใช้อนุมัติชัดเจน

## 9. แผนทดสอบผู้เล่น

Journey A — ผู้เล่นใหม่:

- join → รับฐาน → tutorial → train → pickup → deposit → hatch ภายใน 5 นาที

Journey B — PvP:

- ผู้เล่น A ถือไข่ → B ขโมย → A ได้ feedback → B ส่งที่ฐานของ B → มีเจ้าของผลลัพธ์คนเดียว

Journey C — Recovery:

- ตาย/ออกเกม/รีเซ็ตระหว่างถือไข่, ระหว่าง hatch, ระหว่าง save และระหว่าง mutation event

Journey D — Abuse:

- spam RequestDrop/RequestHatch, ส่ง rarity ผิด, trigger prompt ไกล, teleport ไป zone และ replay request

Journey E — Persistence:

- เก็บ Coins/Speed/creature → leave → rejoin → ข้อมูลตรง → save ซ้ำไม่เพิ่มของ

## 10. การตัดสินใจก่อนเริ่ม build

ค่าเริ่มต้นที่แนะนำ:

- เจ้าของ experience: account/group ของผู้ใช้
- MVP: single place, 8 bases, 2–8 players
- art direction: original stylized fantasy creatures; graybox ก่อน
- persistence: development datastore แยก production
- monetization: ปิดไว้จน private beta ยืนยันว่า core loop สนุก
- trading/rebirth/multi-place: post-MVP

## 11. แหล่งอ้างอิงปัจจุบัน

- Roblox Studio testing modes: https://create.roblox.com/docs/studio/testing-modes
- Roblox publishing: https://create.roblox.com/docs/production/publishing/publish-games-and-places
- Roblox DataStore: https://create.roblox.com/docs/cloud-services/data-stores
- Roblox access control/replication: https://create.roblox.com/docs/scripting/security/access-control
- Rojo project format: https://rojo.space/docs/v7/project-format/
- Rojo build/live sync: https://rojo.space/docs/v7/getting-started/new-game/

## 12. Plan mutation protocol

- ถ้า step ใหญ่เกิน 3 วัน: แยกเป็น schema/implementation/integration ก่อนเริ่มแก้ไฟล์
- ถ้า dependency เปลี่ยน: อัปเดต graph และ exit criteria ในไฟล์นี้ก่อนดำเนินงานต่อ
- ถ้า Studio API/Roblox policy เปลี่ยน: ตรวจเอกสารทางการใหม่ก่อน publish
- ถ้า beta พบ data-loss หรือ duplication: หยุด launch, ปิด persistence write ที่เสี่ยง และเพิ่ม regression test ก่อนแก้
- ห้ามข้าม M3/M7 เพื่อเร่ง public launch
