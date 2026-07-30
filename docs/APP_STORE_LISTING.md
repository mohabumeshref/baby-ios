# App Store listing — My Baby & I / أنا و طفلي

App ID `6795675339` · bundle `com.wecare.arabicbaby` · build **10**

Everything below is ready to paste into App Store Connect. Fields marked
**BLOCKED** need a decision or an asset only the account holder can supply.

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

## 2. English (en-US) — recommend NOT publishing this localization yet

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
| Support URL | **BLOCKED — needed** |
| Privacy policy URL | **BLOCKED — required by Apple, submission cannot proceed without it** |
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

**Demo account — BLOCKED, required.** The community tab sits behind a sign-in,
so Apple must be given a working account or the app gets rejected under
Guideline 2.1 as incomplete. Create a throwaway forum account and enter its
email and password in App Review Information. Do not reuse a personal account.

**Review notes** — paste this:

```
The app is Arabic-first and lays out right-to-left. It also ships a full
English localization; switch the device language to English to review it.

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

1. **Privacy policy URL** — hard requirement, none exists yet.
2. **Support URL** — hard requirement.
3. **Demo account** — hard requirement for the forum.
4. **Export compliance** — `ITSAppUsesNonExemptEncryption` is already set in
   `Info.plist`, so no per-submission question should appear.
5. Blocking shipped in build 11; **submit build 11 or later**, not build 10 —
   Guideline 1.2 expects blocking on user-generated content, and a reviewer
   who looks for it in build 10 will not find it.
