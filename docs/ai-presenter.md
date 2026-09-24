# AI presenter: your digital twin on camera

`npm run presenter` makes one short vertical video of an AI avatar of you presenting a
trending, informational topic:

1. **Pick a lane.** It rotates daily through AI & tech, money & business, trading &
   markets, and food & restaurant life. Force one with `--niche ai|money|markets|food`.
2. **Research what's trending.** Claude searches the live web for the last ~72 hours in
   that lane, skips topics you covered recently, and picks one with verifiable facts.
3. **Write the script.** 45-70 seconds, first person, in a friendly plain-spoken voice,
   using only facts found in the research. It checks the script's length, that no URLs are
   spoken, and that every source actually came from this run's web search. Money and
   markets scripts get a spoken "not financial advice" line.
4. **Render.** HeyGen generates the video with your avatar and your cloned voice (1080x1920).
5. **Save.** Everything goes to `data/presenter/<date>-<lane>-<topic>/`:
   `video.mp4`, `script.json`, `post.txt` (caption, hashtags, sources, AI disclosure),
   `research.md`, `render.json`.

`npm run presenter -- --script-only` does steps 1-3 without spending HeyGen credits, so
you can review scripts first.

## One-time setup

### 1. HeyGen account + API key
Create a HeyGen account on a plan with API access, then copy your API key from the
account's API settings into `HEYGEN_API_KEY`.

### 2. Your avatar (pick one)
- **Best: video avatar (digital twin).** Record 2-5 minutes of yourself talking to the
  camera and upload it in HeyGen's avatar creator. HeyGen will also ask for a short consent
  clip. Tips: film in soft, even front light. Overhead kitchen lighting like in your
  selfies casts shadows under the brows. Use a plain background, the camera at eye level,
  natural gestures, and close your mouth between sentences. Put the avatar's ID in
  `HEYGEN_AVATAR_ID`.
- **Quick start: photo avatar.** Upload a clear, front-facing, evenly lit photo as a
  photo avatar. The straight-on selfie works better than the profile shots. It works
  today, but looks less natural than a video avatar. Put its ID in
  `HEYGEN_TALKING_PHOTO_ID`.

### 3. Your voice
In HeyGen's voice cloning, upload or record 1-2 minutes of you reading naturally in a
quiet room, with no music and no echo. Put the voice's ID in `HEYGEN_VOICE_ID`.

### 4. Find the IDs
```bash
curl -s -H "X-Api-Key: $HEYGEN_API_KEY" https://api.heygen.com/v2/avatars          # avatar_id
curl -s -H "X-Api-Key: $HEYGEN_API_KEY" https://api.heygen.com/v1/talking_photo.list # talking_photo_id
curl -s -H "X-Api-Key: $HEYGEN_API_KEY" https://api.heygen.com/v2/voices            # voice_id
```

### 5. First run
```bash
HEYGEN_TEST=true npm run presenter -- --niche ai   # free, watermarked
npm run presenter                                  # real render, today's lane
```

## Posting it: disclosure
Each `post.txt` ends with a line saying the video uses an AI avatar. Also turn on each
platform's own label. YouTube ("altered or synthetic content"), TikTok ("AI-generated")
and Instagram ("AI info") all require it for realistic AI-generated people. Posting
unlabeled can get videos removed or down-ranked.

## Accuracy
The script can only use facts from that run's research, and its sources are saved with
every video. Still, skim `post.txt` and the sources before posting, especially for
markets and money, where news moves fast.
