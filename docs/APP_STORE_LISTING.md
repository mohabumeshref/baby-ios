# App Store listing — My Baby & I / أنا و طفلي

App ID `6795675339` · bundle `com.wecare.arabicbaby` · submit **build 11 or later**

Ready to paste into App Store Connect. Decisions already made: **Arabic-only
listing**, privacy policy on its own Firebase Hosting site. Section 7 lists what
still has to happen before Submit.

---

## 1. Arabic (ar) — primary localization

**Name** (30 max)

```
أنا و طفلي - تطور طفلك
```

**Subtitle** (30 max)

```
مهارات ومراحل نمو الرضيع
```

**Keywords** (100 max, comma-separated, no spaces)

```
رضيع,مولود,نمو,مهارات,أمومة,تربية,طفلي,أسابيع,تطور,عناية,حديثي الولادة,أم
```

**Promotional text** (170 max — editable without a new build)

```
تابعي مهارات طفلك شهراً بشهر، واقرئي عن تطوره أسبوعاً بأسبوع، وشاركي تجربتك مع أمهات أخريات في مجتمع أنا و طفلي.
```

**Description**

```
أنا و طفلي هو رفيقك في السنة الأولى من عمر طفلك.

• مهارات كل شهر
تعرّفي على ما يستطيع طفلك فعله في شهره الحالي، مقسّمة إلى ثلاث مجموعات:
مهارات أتقنها معظم الأطفال، مهارات بارزة يقوم بها نصفهم، ومهارات متطوّرة.
علّمي كل مهارة يتقنها طفلك وتابعي تقدّمه بنظرة واحدة.

• أسبوعاً بأسبوع
محتوى مفصّل عن نمو طفلك وتطوره خلال السنة الأولى: كيف ينمو، ما الذي يتغيّر،
وكيف يمكنك دعمه — مع تحديد أسبوعك الحالي تلقائياً من تاريخ الميلاد.

• عمر طفلك بلمحة
بالأيام وبالأسابيع وبالأشهر، محسوباً تلقائياً.

• مجتمع الأمهات
اطرحي أسئلتك، وشاركي تجربتك، وأجيبي على أسئلة غيرك. يمكنك الكتابة باسمك أو
بدون إظهار اسمك. المجتمع مشترك مع تطبيق دليل حملي، فإذا كنتِ تستخدمينه
يمكنك الدخول بنفس الحساب.

التطبيق مجاني بالكامل.

ملاحظة: المحتوى في هذا التطبيق للاطلاع العام ولا يُغني عن استشارة الطبيب.
إذا كان لديك أي قلق بخصوص صحة طفلك أو تطوره، راجعي طبيب الأطفال.
```

---

## 2. English (en-US) — DECIDED: do not publish this localization

Kept here for reference only. The Arabic listing is the one to submit.


**The app's interface is localized; its content is not.** Chrome ("This month's
skills", "Your baby's age", tab names) switches to English, but every milestone,
tier title and week-by-week article stays Arabic, because `weeks.json` and
`skills.json` were ported from the Arabic Android app and have no English text.

An English store listing therefore sells an English-language app to people who
would open it and find Arabic content — a poor first impression, a likely
one-star pattern, and a plausible review rejection for a broken localization.

**Recommendation: publish Arabic only for now.** The English app localization
still helps Arabic speakers whose phone is set to English; it just should not be
advertised as an English app.

If you want the English listing anyway, keep the copy below but add this line at
the top of the description so nobody is misled:

```
Note: the milestone and week-by-week content in this app is written in Arabic.
```


**Name** (30 max)

```
My Baby & I - Baby Milestones
```

**Subtitle** (30 max)

```
Baby milestones, week by week
```

**Keywords** (100 max)

```
baby,milestone,newborn,development,growth,parenting,infant,tracker,mom,weekly,arabic
```

**Promotional text** (170 max)

```
Follow your baby's milestones month by month, read how they grow week by week, and share the journey with other parents.
```

**Description**

```
My Baby & I is your companion through your baby's first year.

• Milestones for every month
See what your baby can do this month, grouped into three sets: skills most
babies have mastered, emerging skills about half are doing, and advanced
skills. Check off each one and watch progress fill in at a glance.

• Week by week
Detailed reading on how your baby grows and changes through the first year,
with your current week worked out automatically from their birth date.

• Your baby's age at a glance
In days, in weeks, and in months — calculated for you.

• A parents' community
Ask questions, share what you're going through, and answer other parents.
Post under your name or without showing it. The community is shared with the
Pregnancy Guide app, so an existing account signs straight in.

Completely free.

Note: content in this app is general information and is not a substitute for
medical advice. If you have any concern about your baby's health or
development, talk to your pediatrician.
```

---

## 3. Shared metadata

| Field | Value |
|---|---|
| Primary category | Health & Fitness |
| Secondary category | Lifestyle |
| Copyright | `2026 Mohammad AbuMeshref` |
| Age rating | expect **12+** — the questionnaire's user-generated-content answer drives this |
| Price | Free |
| Contains ads | Yes |
| Support URL | `https://baby-ar-ios.web.app/support` |
| Privacy policy URL | `https://baby-ar-ios.web.app/privacy` |
| Marketing URL | optional, may be left empty |

### Age-rating questionnaire — answers that match the app

| Question | Answer |
|---|---|
| Cartoon/fantasy violence, realistic violence, sexual content, profanity, alcohol/drugs, horror, gambling | None |
| **Unrestricted web access** | **No** — the app has no in-app browser |
| **User-generated content** | **Yes** — the forum. Choose the option that includes moderation/reporting/blocking controls |
| Contests | No |

---

## 4. App Privacy — matches the SDKs actually linked

Linked: FirebaseAuth, Firestore, Messaging, Storage, Analytics, RemoteConfig,
GoogleMobileAds.

| Data type | Collected | Linked to user | Used for tracking | Purpose |
|---|---|---|---|---|
| Email address | Yes | Yes | No | App functionality (account) |
| Name | Yes | Yes | No | App functionality (forum display name) |
| Photos | Yes | Yes | No | App functionality (post/profile images) |
| Other user content | Yes | Yes | No | App functionality (posts, comments) |
| User ID | Yes | Yes | No | App functionality |
| Device ID (IDFA) | Yes | No | **Yes** | Third-party advertising |
| Product interaction / usage | Yes | No | No | Analytics |
| Crash + performance data | Yes | No | No | Analytics |

Because IDFA is used for tracking, **App Tracking Transparency must be
declared** — the app already shows the ATT prompt, and `Info.plist` carries
`NSUserTrackingUsageDescription`.

The baby's **birth date and milestone check-offs never leave the device** —
they live in `UserDefaults`, are not uploaded, and so are not disclosable data.
Worth stating plainly in the privacy policy; it is a genuine selling point.

---

## 5. App Review information

**Demo account — required.** The community tab sits behind a sign-in, so Apple
must be given a working account or the app gets rejected under Guideline 2.1 as
incomplete.

A demo account has been created. **Its credentials are deliberately not written
in this file** — they go straight into the *App Review Information* fields in
App Store Connect, which only Apple can read. This repo already had one
credential leak; a password in a tracked file is the same mistake in a smaller
hat.

Before submitting, sign in with it once in the app to confirm it actually works.
A demo account Apple cannot log into is a rejection.

**Review notes** — paste this:

```
This is an Arabic-language app and lays out right-to-left. All content is in
Arabic. (The interface strings also have English translations for Arabic
speakers whose device is set to English, but the app is not marketed in
English.)

Milestones and week-by-week content work with no account. Only the Community
tab requires sign-in — please use the demo account provided.

User-generated content controls, all in the "..." menu on any post or comment:
- Report content for moderation
- Block a user, which immediately hides all of their posts and comments
- Authors can edit or delete their own content
New posts additionally pass through server-side moderation before appearing
in the public feed.

The community is shared with our Pregnancy Guide app (same developer), which
is why an existing account from that app signs in here.

The app shows ads and asks for App Tracking Transparency permission. Declining
tracking does not restrict any feature.
```

---

## 6. Screenshots

Required: **6.9" iPhone**, 1320 × 2868. Apple scales these down for smaller
iPhones, so this one size covers the whole iPhone range. iPad screenshots are
only needed if the app is offered on iPad.

Generated by `.github/workflows/screenshots.yml` with `-seed_demo 1`, which
serves sample forum posts and suppresses the ad banner and ATT prompt. The
sample posts are invented — the live feed is other parents' personal writing
and must not appear in marketing material.

---

## 7. Before submitting — open items

1. **Deploy the privacy policy.** From `firebase/`:

   ```bash
   firebase hosting:sites:create baby-ar-ios --project pregnancy-tracker-57bf7
   firebase deploy --only hosting:baby-privacy --project pregnancy-tracker-57bf7
   ```

   Confirm `https://baby-ar-ios.web.app/` loads — Apple rejects a 404 here.
   It deploys to a **separate site** from `pt-ar-ios.web.app` on purpose: that
   one serves the pregnancy app's policy, which its live listing points at.

2. **Support URL** — `https://baby-ar-ios.web.app/support`, deployed alongside
   the privacy policy. It carries the contact address and an FAQ covering the
   report/block controls, which is also the "published contact information"
   half of Guideline 1.2.

3. **Demo account** — create a throwaway forum account and put its email and
   password in App Review Information. Without it the Community tab is a
   locked door and the app gets rejected as incomplete. Create this yourself;
   it is a credential, not something to hand to a tool.

4. **Export compliance** — `ITSAppUsesNonExemptEncryption` is already in
   `Info.plist`, so no per-submission question should appear.

5. **Submit build 11 or later, not build 10.** User blocking landed in 11, and
   Guideline 1.2 expects it on user-generated content.

6. **Age rating** — answer the user-generated-content question truthfully;
   expect 12+.
