# zirizima — Privacy Policy

_Last updated: 2026-05-10_

zirizima is a free toilet finder app for Seoul, designed for foreign
tourists. We respect your privacy. This policy explains what data the
app uses, how it uses it, and what we never do.

## TL;DR

- We use your location only to show toilets near you. We never store it.
- You can leave anonymous ratings. We don't know who you are.
- We show contextual ads via Google AdMob. We do not track you across other apps or websites.
- No account, no email, no phone number. We do not access your IDFA.

## Data we use

### Location
The app uses your iPhone's location (via Core Location, "When In Use"
permission) to compute distances to nearby toilets. The location is
sent to our backend only as a one-shot lat/lng pair to query the
nearest entries — it is never written to disk or logged.

You can use the app without granting location: the home screen falls
back to the Gyeongbokgung area (a tourist hotspot in central Seoul).

### Anonymous device identifier
On first launch, the app generates a random UUID and stores it in
`UserDefaults`. This UUID is sent with every rating you leave so that:

1. You can update an old rating you submitted, instead of duplicating it
2. We can rate-limit abusive devices (5 ratings per hour max)

The UUID is **not** linked to your Apple ID, your iPhone serial number,
your IDFA, your IP address, your name, or any other personal identifier.
Deleting the app on your iPhone deletes the UUID (we have no way to
recover it).

### Ratings + tags + comments you submit
When you tap "Rate" and submit, the following is sent to our backend:
- A 1–5 star rating
- Zero or more pre-defined tags (clean, busy, has_paper, etc.)
- Optional one-line comment (≤280 characters)
- The ID of the toilet
- Your anonymous device UUID (see above)
- Your selected app language ("en", "ko", "zh", or "ja")

These are stored on our backend and shown to other users as anonymous
reviews ("Anonymous · 3d ago"). They are not associated with any
identifier other than your device UUID.

## Data we don't use

- Apple ID
- Email address
- Phone number
- IDFA (advertising identifier)
- IP address (we do not log inbound IPs)
- Crash reports tied to identifiable users (we use no third-party crash
  SDK)
- Analytics cookies / usage tracking
- Photos
- Microphone, camera, contacts, calendar, motion, health

## Where data lives

- **Mobile app**: Anonymous device UUID, app language preference
  (UserDefaults). That's it.
- **Backend**: Toilets dataset (public information from the Seoul Open
  Data Plaza), areas, and the ratings you and other users submit.
  Hosted on Supabase Inc., in their AWS Seoul region.

## Third-party services

### Google Maps (handoff)
When you tap "Take me there", the app opens Google Maps with the
toilet's coordinates as a destination. From that moment, you are
interacting with Google Maps and its [privacy policy applies](https://policies.google.com/privacy).
zirizima sends Google nothing — it just opens a URL.

### Supabase (backend host)
Our backend runs on Supabase Inc. (https://supabase.com). They process
the API requests we send them. They do not have access to anything
beyond the toilets database and the anonymous review data described
above.

### Google AdMob (advertising)
We display banner advertisements on the home and detail screens via
the Google Mobile Ads SDK. We do not present the App Tracking
Transparency prompt and do not access your IDFA — AdMob therefore
serves **contextual** (non-personalized) ads only, not behaviorally
targeted across other apps or websites.

To deliver these ads, Google's SDK may automatically collect:
- A device-scoped identifier (IDFV, scoped to zirizima only, not
  cross-app)
- Coarse location at the time of an ad request
- Diagnostic / performance data, user-agent / device model

This data is subject to [Google's privacy policy](https://policies.google.com/privacy).
None of it is linked by us to your ratings or any other identifier on
our side.

## Children's privacy

The app is not directed at children under 13. We do not knowingly
collect any data from anyone, regardless of age.

## Your rights

You can:
- Stop using the app and delete it. This deletes the device UUID. Any
  ratings you submitted in the past will continue to exist as anonymous
  data — there is no way to associate them back to you for deletion,
  because we never associated them in the first place.
- Disable location access for zirizima in iPhone Settings → Privacy.

## Changes to this policy

If we change this policy in a way that materially affects how we
handle your data, we'll update the "Last updated" date at the top.
For non-trivial changes, we'll show a notice in the app on next
launch.

## Contact

Questions? Email: yumdongja@gmail.com

---

# zirizima — 개인정보 처리방침 (한국어)

_최종 수정: 2026-05-10_

zirizima는 서울을 방문하는 외국인 관광객을 위한 무료 화장실 찾기 앱입니다.
저희는 사용자의 개인정보를 존중합니다.

## 요약

- 위치는 근처 화장실을 보여주기 위해서만 사용하고, 저장하지 않습니다.
- 익명으로 별점을 남길 수 있습니다. 누가 남겼는지 저희는 모릅니다.
- Google AdMob을 통해 컨텍스트 기반 배너 광고를 표시합니다. 앱 외부에서 사용자를 추적하지 않습니다.
- 계정·이메일·전화번호 수집 없음. IDFA 접근 없음.

## 수집하는 정보

### 위치
근처 화장실까지의 거리를 계산하기 위해 iPhone의 위치 정보를 사용합니다.
서버에는 일회성으로 위도/경도만 전달되며, 저장이나 로깅하지 않습니다.

### 익명 기기 식별자
앱 최초 실행 시 무작위 UUID를 생성해 UserDefaults에 저장합니다.
이 UUID는 (1) 이전에 남긴 평점 수정 (2) 분당 평점 제한 (악용 방지)
용도로만 사용됩니다.

이 UUID는 Apple ID, IDFA, 전화번호, 이메일, IP 주소 등 어떤 개인 식별
정보와도 연결되지 않습니다. 앱을 삭제하면 UUID도 같이 삭제됩니다.

### 사용자가 남기는 평점/태그/한줄평
"평가하기"에서 제출하는 정보:
- 1~5점 별점
- 미리 정의된 태그 (깨끗함, 붐빔, 휴지있음 등)
- 선택적 한 줄 코멘트 (최대 280자)
- 화장실 ID, 익명 기기 UUID, 선택한 언어

이 데이터는 익명으로 다른 사용자에게 표시됩니다.

## 수집하지 않는 정보

Apple ID, 이메일, 전화번호, IDFA, IP, 사진, 마이크, 카메라, 연락처,
캘린더, 모션, 건강 정보 등.

## 제3자 서비스

- **Google Maps** — "안내 시작" 시 외부 앱으로 핸드오프합니다.
- **Supabase** — 백엔드 호스팅. AWS 서울 리전.
- **Google AdMob** — 홈/상세 화면 하단에 컨텍스트 기반 배너 광고를 표시합니다. ATT 프롬프트를 띄우지 않고 IDFA에 접근하지 않으므로 개인화 광고는 제공되지 않습니다. Google SDK는 IDFV, 대략적인 위치, 진단 데이터를 자동 수집하며 [Google 개인정보 정책](https://policies.google.com/privacy)의 적용을 받습니다.

## 문의

yumdongja@gmail.com
