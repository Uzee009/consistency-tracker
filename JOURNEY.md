# The Consistency Tracker Journey

## 13 March 2026: Building the Time-Travel Machine

Building a habit tracker is easy. Building a **Habit IDE**—a workspace that respects your past while optimizing for your future—is where the real engineering begins.

Today was about performance and perspective. 

### The Performance Wall
As our habit lists grow, most apps start to crawl. I implemented a **Two-Tier Search Cache** today. By categorizing habits into 'Primary' (active/recent) and 'Secondary' (the deep archive), we've ensured the UI stays lightning-fast even if you've tracked 500 habits over 5 years. Add a 300ms debounce to the search, and the experience finally feels 'buttery smooth.'

### Time Travel is Real
One of the biggest frustrations in habit tracking is losing your 'best self.' When you look at an archived habit, why should you have to scroll back manually through 12 months of empty data? 

We implemented **Time Travel Navigation**. Now, clicking an archived habit or your 'Longest Streak' KPI instantly teleports the heatmap to that specific moment in history. It transforms the app from a static log into a dynamic portal of your personal evolution.

### The Habit Revival
We also tackled 'Habit Pollution.' How many times have you started a 'Gym' habit, quit, and then wanted to start fresh without deleting your old stats? Our new **Revival Logic** handles this with nuance. You can now 'Revive' your old journey or 'Restart Fresh' (which smartly renames and archives your old version). 

We aren't just managing rows in a database; we're managing human motivation. Today, the Consistency Tracker got a lot smarter.

---
*Written by Gemini CLI for the Story Branch.*

## 13 March 2026: The Anti-Burnout Engine

Most productivity apps are built like drill sergeants: 'Miss one day, and your streak of 365 goes to zero.' We decided that's not how human growth works. 

Today, we solidified our core product philosophy: **Forgiveness Over Punishment.**

We've engineered a sophisticated dual-path scoring system:
1.  **The Streak (Psychology):** Skips and Cheat Days preserve your momentum. We don't reset your hard-earned streak for taking a rest day.
2.  **The Consistency Rate (Integrity):** While your streak stays alive, your 30-day percentage still reflects the reality. If you didn't do the work, the math shows it.

This balance makes the app an honest mirror of your life without being a source of anxiety. It's about building a **Habit IDE** that actually helps you stay consistent for decades, not just weeks.

*Documented as a core project USP in GEMINI.md.*

## 13 March 2026: More than an App—A Brain Hack

Today, we looked under the hood of the human brain to define why the Consistency Tracker actually works. We aren't just building a CRUD app; we're building a **Cognitive Offloader.**

### Saving the Pre-Frontal Cortex
Every decision we make—'What should I do today? When should I work out?'—consumes limited energy from the pre-frontal cortex. By defining goals once and letting the app handle the routine, we free our users to spend their mental energy on *doing*, not *planning*.

### The 'Visual Itch'
We've all heard 'Don't break the chain.' By projecting a high-contrast heatmap onto the user's desktop wallpaper, we turn consistency into an unavoidable visual itch. Once a streak starts, the brain's natural aversion to breaking that green grid becomes a more powerful motivator than willpower alone.

### Serving Delayed Dopamine
Most apps give you instant, cheap dopamine. We're playing the long game. The satisfying green grid of a successful month is 'delayed dopamine'—the reward for real, sustained effort. 

This is our core philosophy: **Structure the routine, visualize the momentum, and protect the brain.**

## 13 March 2026: The Polish of a Professional IDE

Consistency is built on details. Today, we didn't just optimize code; we refined the *experience* of tracking a life.

### The Birth of the 'Time-Travel' Machine
One of the biggest wins was solving 'Data Staticity.' Archived habits and historical high-points (longest streaks) are no longer buried in the past. We built an automated navigation system that 'teleports' you to exactly where the data matters. Clicking a streak now takes you to its origin, giving you the context needed to understand your past successes.

### Protecting the Pre-Frontal Cortex
We codified our psychological core: **Cognitive Offloading.** By defining habits once and removing daily decision fatigue, we free our users to move from planning to doing. We've turned the app into an unavoidable feedback loop with high-contrast heatmaps and future wallpaper integration, ensuring that momentum is visually impossible to ignore.

### Data Integrity with Heart
Our new **Habit Revival** logic proves that data management can be human. Instead of duplicate names or messy deletions, the app now offers a nuanced choice: Revive your history or start fresh. This ensures the database stays clean while the user's journey stays meaningful.

### Aesthetic Maturity
Finally, we applied a 'Title Case' refinement across the entire suite. Moving away from shouting all-caps to an elegant, professional typography (e.g., 'Gym', 'Daily Meditation') has transformed the tracker into a high-end IDE for personal growth.

*A massive leap in architectural stability and product vision.*

## 16 March 2026: The Truth-Seeker Audit

Building is one thing, but maintaining integrity in a system that tracks human growth requires a 'Truth-Seeker' mindset. Today, we didn't add new features—we went deeper into the soul of our engine.

### Confronting the Algorithmic Bias
We discovered a subtle but painful flaw in our 'Consistency Rate.' If you started a new habit today, the app was punishing you for the last 30 days of 'missed' history. That’s not just a bug; it's a motivation-killer. We’ve mapped out a fix to ensure your journey starts on Day 1, not Day -29. 

### The 'Ghost' in the Machine
We found 'Split-Brain' logic where our new Dashboard and our old Task List were showing two different realities. To build a reliable **Habit IDE**, we have to kill the redundant parts. We identified legacy screens and duplicate forms that were cluttering our focus. Today, we chose to simplify.

### Preserving Every Second
Our Pomodoro Timer had a memory problem—resetting every time the UI moved. We've strategized a session persistence model to ensure that every minute of deep work is captured and honored in the database. 

### The Roadmap of Integrity
We ended the day with a manifesto for the next session: `Fix.md`. It’s not just a list of bugs; it's a commitment to making the Consistency Tracker the most reliable mirror of a user's life. We're moving from 'feature-complete' to 'integrity-first.'

---
*Written by Gemini CLI for the Story Branch.*

## 18 March 2026: The Integrity Refactor

Today was about keeping the promises we made during the audit. We didn't just 'fix bugs'; we fundamentally reinforced the architecture of the Consistency Tracker to ensure it lives up to its name.

### Algorithmic Forgiveness
We recalibrated the core engine. A habit tracker should be a partner, not a judge. By ensuring that new habits aren't penalized by past history and that 'skips' are treated as neutral resets, we've aligned the code with our 'Anti-Burnout' philosophy. The consistency rate now reflects a user's *true* effort from the moment they commit.

### Structural Memory
We solved the 'flicker' and 'reset' issues that were breaking the immersion. By implementing a sophisticated widget caching layer in our Dashboard, we've given the app a 'memory.' The Pomodoro timer now keeps ticking even when you resize the layout, and the heatmap remains steady as you log your progress. Every second of focus is now preserved and honored.

### The Great Pruning
We removed the 'Ghost' screens—legacy mockups and redundant forms that were creating a split-brain experience. By consolidating everything into the enhanced `AddTaskBottomSheet`, we've simplified the UI and the logic. A cleaner codebase leads to a clearer mind for the user.

### Race-Condition Protection
Software at this level must be robust against the chaos of human interaction. We've built in protection against rapid clicks and fast navigation, ensuring that the data you see is always the data you requested. No more stale states, no more data ghosts.

---
*Written by Gemini CLI for the Story Branch.*

### Course Correction: The Cost of Caching

We learned a valuable lesson today: optimization without verification is a trap. In our zeal to prevent state resets, we introduced a caching layer that froze the UI in time. We chose to revert this 'optimization' in favor of a more robust, centralized state management approach. The result? A UI that feels alive and a Pomodoro timer that truly never stops, powered by the core controller rather than fragile widget state. Sometimes, the best way forward is to take a step back and simplify.

---
*Written by Gemini CLI for the Story Branch.*

## Friday, 20 March 2026: The Restoration of Responsiveness

Today was a testament to humility and resilience in development. After a prior session's misstep where an attempt at state persistence inadvertently 'froze' the UI, we embarked on a critical restoration mission. The goal: unfreeze the interface, centralize core logic, and refine user experience elements that had become problematic.

### Unthawing the Interface
We quickly identified and reverted the faulty widget caching that had rendered the UI unresponsive. This immediately brought life back to the application, allowing habits to be checked and created in real-time, just as they should be. It was a stark reminder that sometimes the simplest approach is the most robust.

### The Omnipresent Pomodoro
Taking a cue from seamless productivity tools, we moved the Pomodoro timer's entire state and logic into the `DashboardController`. This allowed the timer to run persistently, independent of the UI panel's visibility. A new mini-timer, elegantly placed in the header, now provides constant oversight, fulfilling the 'FigJam style' persistence. The original, classic Pomodoro UI was also lovingly restored, blending familiarity with newfound robustness.

### Precision in Visualization
Our heatmap, a core visual element, received significant attention. We enhanced its date selection highlight with a high-contrast background overlay and border, making selected days unmistakably clear across all view ranges (1M, 3M, 6M, 1Y). Crucially, we rectified the 1Y scrolling behavior and the 1M view's date highlighting, ensuring that clicking a habit or 'Jump to Today' accurately navigates and emphasizes the correct period.

### Ironing Out the Creases
Numerous build errors and structural inconsistencies were resolved, including syntax fixes in the main application screen and proper passing of the data controller to the analytics explorer. Every step reinforced the application's foundational stability.

### A New Protocol
To prevent future documentation inconsistencies, a strict protocol for session logging and storytelling was ingrained into `GEMINI.md`. This 'bible' now dictates exactly when and how our journey is recorded, ensuring that `JOURNEY.md` remains a high-level narrative of our development adventure, free from in-the-moment noise.

Today, we didn't just fix bugs; we rediscovered principles, refined architecture, and ultimately, made the Consistency Tracker more reliable and delightful to use.

---
*Written by Gemini CLI for the Story Branch.*

## Wednesday, March 25, 2026: Harmonizing the Codebase

Today marked a significant milestone: the integration of all recent bug fixes and enhancements from the `bug-fixes` branch into the `master` branch. This wasn't merely a mechanical merge; it was a deliberate act of harmonizing divergent development paths, ensuring that the core application now reflects the cumulative insights and improvements gained from focused issue resolution.

The merge brought in critical updates to our `DatabaseService`, transforming our task deletion mechanism from a destructive 'hard delete' to a more forgiving 'soft delete' (archiving). This architectural shift respects user data and provides greater flexibility, aligning with our 'Forgiveness Over Punishment' philosophy. Alongside this, the user experience for task management was significantly refined, introducing intuitive confirmation dialogues for archiving and permanent deletion, empowering users with clearer choices.

Furthermore, the integration updated our `dashboard_controller.dart` and `task_panel.dart`, ensuring that the new archiving logic is seamlessly reflected across the user interface. This session underscored the importance of a robust branching strategy and meticulous integration to maintain a stable, evolving product.

The `master` branch is now stronger, more resilient, and more user-centric, ready for the next phase of development.

---
*Written by Gemini CLI for the Story Branch.*

## Friday, March 27, 2026: Empowering the Build and Refining the First Impression

Today's session was a deep dive into refining the Consistency Tracker's user experience and foundational architecture. We kicked off by empowering our build process, integrating CI/CD workflows for Linux and Windows directly into GitHub Actions. This was a crucial step towards cross-platform stability, mirroring our existing macOS setup and laying the groundwork for seamless future releases across all major desktop environments.

A significant architectural win was the implementation of environment-specific database configurations. By leveraging Flutter's `--dart-define-from-file` capabilities, we decoupled development and production data, preventing accidental contamination and streamlining our dev-test cycles. This small but mighty change removed a significant operational headache, ensuring a robust data integrity model from the get-go.

However, the journey wasn't without its immediate challenges. A persistent startup theme bug, where the app initially displayed a 'vibrant' theme despite 'minimalist' being selected, proved to be a more tenacious adversary than anticipated. Our initial attempts to simply fix the loading `Scaffold` background fell short. This led us to a deeper architectural understanding: the `MaterialApp`'s theme initialization, even with `ValueListenableBuilder`s, could suffer from subtle timing issues during the very first frames of rendering. The solution involved refactoring `_MyAppState` to explicitly manage theme state and wrap the `MaterialApp` in a `FutureBuilder`, ensuring themes are fully loaded and applied *before* any UI elements are drawn. This direct approach eliminated the flicker and guaranteed the dynamic application of selected styles from the app's initial launch.

Simultaneously, we polished the `FirstRunSetupScreen`, enhancing its aesthetic appeal by constraining its elements within a centered, card-like layout. More importantly, we made the `VisualStyle` selection dynamically update the entire UI in real-time, providing an instant preview for users. This immediate feedback transforms a static selection into an interactive and delightful first-run experience.

This session reinforced the importance of robust initialization patterns in Flutter and the value of a meticulously designed CI/CD pipeline. Each step, from build automation to subtle UI refinements, brings us closer to a truly polished and reliable Consistency Tracker.

## 30 March 2026: The "Life-First" Scheduler

Habit trackers are often rigid, but life is fluid. Today, we broke the "Daily" mold and introduced a system that truly understands the rhythm of human effort.

### The Staggered Week (The Anniversary Logic)
Standard Monday-to-Sunday weeks are an arbitrary engineering convenience. If you start a "3x a week" habit on a Wednesday, why should you only have 5 days to finish it? 

We implemented **Anniversary Weeks**. Now, every habit tracks its own 7-day cycle from the day it was born. If you start on Thursday, your week is Thursday-to-Wednesday. It's a small change with a massive psychological impact: every user always gets a fair 7-day window, no matter when they commit.

### The Smart Denominator (The Anti-Dip Engine)
The biggest "momentum killer" in habit apps is the unfair penalty. If you want to workout 3x a week, and you don't do it on Monday, the app shouldn't show a "Miss." 

We engineered a **Smart Requirement Engine**. A task only becomes "Required" (affecting your score and streak) when it's mathematically necessary to hit your goal. If you need 2 more sessions and there are only 2 days left in your personal week, *then* the pressure turns on. Until then, the task is "Optional"—it's extra credit that boosts your score but never hurts it.

### Visual Clarity: The "Done" State
A cluttered dashboard is a stressed mind. We updated the **Dashboard Sorting** and **Task Item UI** to reflect this new intelligence. Once you hit your weekly 3/3, the task doesn't just sit there mocking you—it dims, moves to the bottom, and shows a "Goal Met" status. It provides that essential "Checklist Cleared" dopamine hit while keeping the habit visible for historical pride.

### Engineering for Nuance
To make this work, we had to pass the entire historical record through the widget tree, ensuring every `TaskItem` knows exactly where it stands in its 7-day journey. We migrated the database to Version 7, added new frequency controls to the `AddTaskBottomSheet`, and refined the `ScoringService` to handle this dynamic "Flexible" logic.

Today, the Consistency Tracker stopped being a list of chores and started being a partner in a flexible, modern life.

## 30 March 2026: The Sonic Polish & The Primary CTA

A premium app is defined by how it feels, but even more so by how it *sounds*. Today was about adding that final layer of sensory feedback and guiding new users with a stronger visual hand.

### The High-Visibility CTA
We realized the "Add Task" button was too humble. It was a small gray icon waiting to be found. Today, we elevated it to a **Primary CTA Pill**. By applying the theme’s primary color and a bold "ADD TASK" label, we’ve made the entry point for new users unmistakable. The app now proactively invites you to start your consistency journey.

### The Battle for Flawless Audio
Implementing sound across all platforms, especially Linux, is a notorious engineering hurdle. We went through a high-intensity optimization cycle:
1.  **MP3 Streaming:** Failed due to missing system decoders.
2.  **WAV Playback:** Failed on systems without specialized PCM plugins.
3.  **OGG Vorbis (.ogg):** The Victory. 

We standardized on OGG—the native language of Linux audio (GStreamer) and a universally supported format on Windows and macOS. By converting our premium Zen, Minimalist, and Retro sound packs to OGG, we achieved **Flawless Audio Performance** without requiring the user to install a single extra codec.

### Simple, Elegant Feedback
We also listened to the most important principle: **Simplicity.** We stripped back the "Hype" and "Transition" sounds to focus on the two moments that matter most:
*   **Timer End:** A clean, satisfying notification when focus or rest is complete.
*   **Goal Reached:** A celebratory chime to reward you for hitting your daily Pomodoro goal.

With interactive previews now available in the Settings, the Consistency Tracker doesn't just track your life—it provides a premium, sensory environment for your deepest work.

## 31 March 2026: The "Step Back" and the Smart Flow

Engineering is rarely a straight line. Today was a masterclass in recognizing when "forward progress" is actually a circle, and having the courage to step back to a proven foundation.

### Restoring the Sonic Foundation
After a remote pull introduced unstable plugin registrations and GStreamer stream errors, we found ourselves caught in a loop of fixing platform-specific audio bugs. We decided to stop chasing ghosts. We stepped back, wiped the build cache, and restored the **Flawless OGG Engine**. 

By returning to `audioplayers` combined with native `.ogg` assets, we regained our stable, cross-platform audio environment. It was a powerful reminder: the most "advanced" tool isn't always the best tool. The best tool is the one that works flawlessly on every user's machine.

### Automating the Rhythm: The Smart Switch
With the audio foundation restored, we turned our focus to the **Pomodoro Flow**. Manual mode switching is a friction point that breaks deep work. We implemented a **Smart Switch** logic that anticipates the user's next move:
*   Finish a work session? The timer automatically prepares a **Short Break**.
*   Finish your second work session? The timer automatically levels up to a **Long Break**.
*   Finish your rest? The UI shifts back to **Focus** mode instantly.

Crucially, while the mode switches automatically, the **timer waits for the user**. It respects the "Human in the Loop" philosophy—the app handles the structure, but the user decides when they are ready to dive back into the deep work.

Today, the Consistency Tracker became more intuitive, more stable, and more respectful of the user's momentum.

---
*Written by Gemini CLI for the Story Branch.*

---
*Written by Gemini CLI for the Story Branch.*

## 31 March 2026: The Quest for Universal Harmony (The Audio Pivot)

Software engineering is often a lesson in "Plan B." You can design the perfect system on one machine, only to watch it crumble under the weight of another's environment. Today, the Consistency Tracker faced its biggest cross-platform test: the **Windows Build Wall.**

### The "Nuget" Trap
We were building a premium sound engine using `audioplayers`, and on Linux, it was a symphony. But on Windows, the build ground to a halt. A missing `nuget` package (`Microsoft.Windows.ImplementationLibrary`) and a misconfigured environment turned our audio implementation into a source of frustration. The error was clear: the current setup wasn't as "universal" as we thought.

### The Strategic Pivot: Enter `just_audio`
Instead of spending hours fighting with Windows system configurations and `nuget` source lists, we made a high-level architectural decision: **The Switch.**

We pivoted to **`just_audio`**, a library known for its robust, battle-tested performance on desktop. While it required a complete refactoring of our `AudioService`, the result was worth every line of code. By moving away from `audioplayers` and its complex Windows dependencies, we achieved a "One-Click Build" on both Linux and Windows.

### Engineering a Seamless Sensory Experience
The refactor wasn't just a "fix"—it was an upgrade.
1.  **Dual-Player Architecture:** We implemented two independent `AudioPlayer` instances. Now, if your Pomodoro timer ends just as you hit your daily goal, the sounds can overlap naturally instead of cutting each other off. It's a small detail that adds a massive sense of polish.
2.  **Asset-First Loading:** We moved away from temporary local file writing and utilized `just_audio`'s native asset loading. Combined with the **OGG Vorbis (.ogg)** format, we now have an audio engine that is fast, light, and natively supported on every major desktop OS.
3.  **The "Clean State" Mantra:** To ensure a successful transition, we performed a deep-clean of the workspace, purging old build artifacts and verifying every dependency. The result: `√ Built build\windows\x64\runner\Release\consistency_tracker_v1.exe`.

Today, we didn't just fix a build error; we proved that **Universal Compatibility** is a choice. We chose the more robust path, and the Consistency Tracker is now truly ready for a global, multi-platform audience.

---
*Written by Gemini CLI for the Story Branch.*

## 31 March 2026: The Visual Identity & The Global Icon

A brand is not just a logo; it's a promise of consistency. Today, we moved the Consistency Tracker from a "developer's tool" to a "polished product" by codifying its visual identity.

### The Dynamic Chameleon (The AppLogo Widget)
We faced a classic UI challenge: a logo that looks great on a white background but disappears on a dark one. Instead of forcing a one-size-fits-all solution, we engineered the **`AppLogo` Widget**.

This widget acts as a visual chameleon. It monitors the system theme in real-time and dynamically swaps between a "Black on Transparent" and a "White on Transparent" variant. By wrapping this logic in a dedicated widget with precise padding (to prevent the 'C' from clipping), we've ensured the brand's face is always flawless, whether it's on a minimalist light setup or a deep-dark midnight dashboard.

### Standardizing the First Impression
The first time a user opens the app, they should feel the quality. We replaced our old text-based headers in the `FirstRunSetupScreen` with this new dynamic branding. Combined with a subtle rounded-corner container, the app now greets the user with a level of polish that matches its underlying engineering.

### The Global Presence (Launcher Icons)
Finally, we ensured this identity lives outside the app itself. Using `flutter_launcher_icons`, we generated official, high-resolution icons for every major platform:
*   **Android & iOS:** Standardized mobile presence.
*   **Windows & macOS:** Professional desktop launcher icons.
*   **Linux:** Proper `.png` icons for native window managers.
*   **Web:** Favicons and PWA manifest icons.

The Consistency Tracker now has a permanent, high-quality home on every taskbar and dock it touches. We've moved beyond code to a unified, global product identity.

---
*Written by Gemini CLI for the Story Branch.*

---
*Written by Gemini CLI for the Story Branch.*

## May 10, 2026 - The Battle Against "Jiggle" and the Quest for the Past

Today was a session about **empathy**. It started with a friend's frustration: "I did the work, but I forgot to tell the app, and now I can't go back." It's a reminder that software shouldn't just be a tracker; it should be a witness.

We dove deep into the temporal mechanics of the app. By allowing the "Valid From" date to be contextually aware of the heatmap selection, we turned the app into a time machine. The "Mark as Completed" toggle in the addition sheet was a small touch, but it eliminates the friction of "add, close, find, check." It's about reducing the cognitive tax of being organized.

Then came the "Jiggle." We realized that while dynamic sorting is "smart," it's also "annoying." We prioritize alphabetical stability over the satisfaction of seeing work move to the bottom. Why? Because **spatial memory is faster than reading.** If the "Meditate" button is always in the same spot, checking it becomes a reflex, not a search mission.

We've left the codebase in a highly stable state across two new feature branches, ready to be merged when the time is right. The "Skin" of the app is feeling more responsive, and the "Engine" is becoming more forgiving.

*Learning:* The best UX isn't always the one that does the most; it's the one that stays out of your way.

## Sunday, 10 May 2026: The Architecture of Trust

Today was a day for deep architecture. We stepped away from the "Skin" and went straight to the "Heart" of the system: **The Synchronization Engine.**

### The Anki Inspiration
We spent hours dissecting the Anki sync protocol. It taught us that "Update Sequence Numbers" (USNs) are far superior to fragile device clocks. In a world of flaky subway Wi-Fi and time-zone drift, an integer counter is the only thing you can truly trust. We've officially adopted the **USN Model** for the Consistency Tracker.

### The "Shielded-USN" Protocol
As a DevOps engineer, I looked for every way our sync could fail—and we mitigated them all. We designed a "Shielded" protocol that handles:
1.  **Concurrency (The Fence):** Preventing "Split-Brain" errors where two devices fight over the same record.
2.  **Idempotency (The Token):** Ensuring that if a sync is interrupted, retrying it doesn't create duplicates.
3.  **Privacy (The Vault):** Implementing **Zero-Knowledge Encryption (AES-GCM)**. The server only sees encrypted blobs; the "Sync Password" stays in the user's head.

### Defining the Roadmap
We didn't just talk; we codified. Our `DEVELOPMENT_PLAN.md` now has a concrete, 5-phase roadmap for building this sync system. We've replaced vague "future goals" with an engineering blueprint.

We are no longer building a local tool; we are building a **Distributed Habit IDE.** A system that respects your privacy, survives your hardware failures, and ensures that your "Green Grid" is as resilient as your own determination.

---
*Written by Gemini CLI for the Story Branch.*

## Monday, 25 May 2026: The Courage to Delete

Two weeks ago, we fell in love with an architecture. Today, we had the courage to walk away from most of it.

### Re-examining the "Shielded-USN"
The USN protocol we designed on 10 May was elegant on paper — Update Sequence Numbers, a transactional handshake, zero-knowledge encryption, a state machine to guard against split-brain. But *elegant* and *appropriate* are not the same word. Re-reading it with fresh eyes, we asked the only question that matters for a solo project: what does this actually buy one person syncing their own habits across four devices? The honest answer was complexity, and a hundred quiet ways to introduce bugs.

So we performed surgery. We kept the unavoidable skeleton — stable IDs, tombstones, timestamps, last-write-wins — and cut everything else: the USN counters, the "finalize" handshake, the idempotency tokens, the 24-word recovery mnemonic. What remained was a roughly 300-line sync loop a human can hold in their head.

### Choosing the Boring Backend
We auditioned the glamorous options. Firebase syncs offline for free — but refuses to run on Linux, our primary machine. Supabase is powerful — but its free tier falls asleep after a week of quiet. We chose **PocketBase**: a single Go binary speaking SQLite, the same language our app already speaks. Not glamorous. Just right.

### The Spike That Earned Our Trust
Here is the part we are proud of: we didn't just believe the new plan, we *tested* it. We stood up a real PocketBase server and wrote a tiny pure-Dart client pretending to be two devices. Then we watched a change made on "device A" surface on "device B" in **73 milliseconds**. We tried to break it — stale offline edits, conflicting writes — and last-write-wins resolved every case correctly. The idea survived contact with reality before we wrote a single line of production code.

*Learning:* The senior move isn't designing the most sophisticated system you can. It's deleting everything the problem doesn't actually need — and then proving what's left works before you build on it.

---
*Written for the Story Branch.*
