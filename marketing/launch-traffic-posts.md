# Pre-launch traffic posts — Hummingbird

Paste-ready posts to point people at the TestFlight beta before App Store launch.
Every one leans on the honest, private, "never advice" identity — that *is* the
differentiator, so don't sand it off into hype. Communities below are
self-promo-averse; lead with substance, not a pitch.

**Lead with the product's one job:** an honest, on-device statistical *sketch* of
where a stock or coin could drift, plus a public record of how wrong it's been.
The self-scoring "practice" loop (direction calls, a practice portfolio) is a
secondary, **opt-in** layer that's off by default — mention it as a bonus, never
as the headline.

- **TestFlight:** https://testflight.apple.com/join/nzpZNbZz
- **Landing:** https://avaj845.github.io/Hummingbirdv1/

**Honesty guardrails (apply to all):** never imply predictions/advice/returns;
say "educational sketches," "a record of the past," "on-device, no tracking";
own that it's early and n=1. The humility is the hook, not a liability.

---

## 1) Show HN (Hacker News)

**Title (≤80):**
`Show HN: Hummingbird – on-device iOS app that publishes its own forecast error rate`

**Body:**
```
I built an iOS app that does the opposite of every "stock prediction" app: instead of selling you certainty, it draws a simple, honest "sketch" of where a stock or coin could drift over the next few days from public prices — then openly publishes how wrong those sketches have been.

Two things I cared about:

1. Honesty over hype. Several classic methods (drift, trend, Holt, momentum, mean-reversion) each sketch a path, and you see where they disagree. Every sketch gets a reliability score with the math shown, and an accuracy report tracks how far past sketches landed from the real price once it caught up — misses included. It never gives buy/sell signals or advice.

2. Privacy by construction. Everything runs on-device in SwiftUI. No account, no backend, no analytics, no tracking — your watchlist and history never leave your phone. The marketing site has no trackers either; the "waitlist" is just Apple's TestFlight, so I collect nothing.

There's also an optional, off-by-default practice mode: you can log a direction call before looking, or run a $10k virtual portfolio, purely to check your own calibration over time. It's a side feature, not the point.

TestFlight: https://testflight.apple.com/join/nzpZNbZz
Site (no trackers): https://avaj845.github.io/Hummingbirdv1/

Happy to talk about the on-device forecasting, the reliability scoring, or the "no backend" architecture.
```
*Notes: post Tue–Thu ~8–10am ET. Reply fast and technically. HN rewards candor about limits and dislikes marketing tone — keep it plain.*

---

## 2) Product Hunt (Upcoming → launch)

- **Name:** Hummingbird
- **Tagline (≤60):** `Honest on-device price sketches — misses and all`
- **Topics:** iOS, Fintech, Privacy, Productivity
- **Description:**
```
Most market apps sell certainty they don't have. Hummingbird does the opposite: it draws simple, transparent "sketches" of where a stock or coin could drift from public prices — and publishes how wrong those sketches have been.

• On-device & private — no account, no backend, no tracking, nothing collected.
• Honest by design — several classic methods sketch a path, each with a reliability score and the math shown, plus an accuracy report that owns its misses. Never advice, never signals.
• Optional practice mode (off by default) — log a call before you look, or run a $10k virtual portfolio, just to check your own calibration.

Educational, not financial advice.
```
- **First maker comment:**
```
Hi PH 👋 I'm the (solo) maker. I got tired of finance apps that project confidence they can't back up, so I built the opposite — an app that draws a modest sketch from public prices and then shows you, in public, how far its past sketches landed from reality.

It's fully on-device — no account, no servers, no tracking (the site has no trackers either). It's early, so I'd love brutally honest feedback from the beta. Never advice — just an honest mirror. 🐦
```
*Notes: build the "Upcoming" page now to collect PH followers; launch 12:01am PT, ideally Tue–Thu.*

---

## 3) Reddit (follow each sub's rules — value first, link last)

### r/iOSProgramming (Feedback Friday, or a "built with SwiftUI" post)
**Title:** `[Feedback] Fully on-device market app in SwiftUI — no backend, no tracking`
```
Solo project: an iOS app that draws simple on-device forecast "sketches" for stocks and crypto and publishes its own error rate. Everything is on-device SwiftUI — no server, no accounts, no analytics — so the whole history lives in the app group and never leaves the phone.

Some bits I'd love feedback on: the reliability scoring (prior tracking + current conditions + horizon), an @Observable store architecture with pure engines + walk-forward tests, and keeping it genuinely tracker-free.

TestFlight if you want to poke at it: https://testflight.apple.com/join/nzpZNbZz — honest critique very welcome.
```

### r/SideProject
**Title:** `I built an app that draws honest price sketches and then shows how wrong they were (on-device, no tracking)`
```
The pitch is basically anti-hype: it won't tell you what a stock will do. It draws a simple sketch from public prices, scores how reliable that sketch is, and keeps an accuracy report of how far past sketches landed from the real price.

There's also an optional practice mode (off by default) if you want to check your own calibration — but the core is just the honest sketch.

Fully on-device, no account, no tracking. Free beta on TestFlight: https://testflight.apple.com/join/nzpZNbZz. It's early — would love feedback on whether the honesty framing lands.
```

### r/TestFlight
**Title:** `[Beta] Hummingbird — honest, on-device price sketches (no account, no tracking)`
```
Draws simple forecast sketches for stocks and crypto from public prices, gives each a reliability score with the math shown, and publishes an accuracy report of its own misses. Optional off-by-default practice mode (log a call, or a $10k virtual portfolio) for calibration. On-device, private, educational — never advice.

TestFlight: https://testflight.apple.com/join/nzpZNbZz
Feedback thread welcome — especially bugs and whether the honesty framing is clear.
```
*Notes: never cross-post the same text; space posts out; reply to every comment. Avoid investing subs (r/investing, r/stocks) — they remove self-promo and it's off-tone.*

---

## 4) X / Twitter thread (founder, honest-forecasting angle)

```
1/ I built an iOS app that does the opposite of every stock-prediction app.

It won't sell you certainty. It draws a modest sketch of where a price could drift from public history — then publishes, in public, how wrong its past sketches have been.

Here's the thinking 🧵

2/ Every "forecast" app hides its track record. This one leads with it.

An accuracy report shows how far past sketches landed from the real price once it caught up. Misses included. That record is the product.

3/ How a sketch is built:

• Several classic methods (drift, trend, Holt, momentum, mean-reversion) each sketch a path
• You see where they disagree
• Each sketch gets a reliability score, with the math shown

No signals. No advice. A mirror, not a guru.

4/ It's also private by construction:

100% on-device SwiftUI. No account, no backend, no analytics, no tracking. Your watchlist and history never leave your phone. (The website has no trackers either.)

5/ Optional, off by default: a practice mode.

Log a direction call before you look, or run a $10k virtual portfolio — purely to check whether your own gut is calibrated over time. A side feature, not the headline.

6/ It's early and unproven — which is the whole point. The honest error rate is right there.

Free beta on TestFlight 👇
https://testflight.apple.com/join/nzpZNbZz

Educational, never advice. Brutally honest feedback welcome.
```

**LinkedIn variant (one post):** paste tweets 1–4 as paragraphs + the CTA; add a line: "If you build things and care about honest, private software, I'd love your feedback."

---

## 5) Reusable one-liner (bios, comments, DMs)
```
Hummingbird — honest, on-device price sketches for stocks & crypto that publish how wrong they've been. Private, no account, never advice. Free TestFlight beta: https://testflight.apple.com/join/nzpZNbZz
```

---

## Posting cadence (first ~2 weeks)
1. **Now:** X/LinkedIn thread + r/SideProject + r/TestFlight. Build the PH "Upcoming" page.
2. **A few days later:** r/iOSProgramming (Feedback Friday).
3. **When you have a few testers + fixes:** Show HN (Tue–Thu am ET) — highest-variance, highest-upside; only fire it once.
4. **After some validation:** Product Hunt full launch.

Reply to every comment fast. One good HN/PH day can spike TestFlight joins — which is the actual goal (real testers = validation), not vanity signups.
