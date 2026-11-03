#include <stdint.h>

// Who is allowed to play, decided with no UIKit and no YouTube in sight so a host test can run
// the same code the tweak ships (tweaks/youtube/tests/host/Test_Arbiter.m).
//
// There are two players in one process -- YouTube's own and the Download Centre's -- and the
// audio session cannot arbitrate between them (it only separates *apps*). So exactly one of
// them is the **owner** at any time, and everything shared follows the owner: the lock screen's
// Play button, the "now playing" entry, the audio session.
//
//   ours   the Centre's player was started or commanded by the person.
//   host   YouTube's player started *audibly* on its own, outside the moment of one of our commands.
//   none   neither has played yet, or ours was closed.

typedef enum { SCIOwnerNone = 0, SCIOwnerOurs = 1, SCIOwnerHost = 2 } SCIOwner;

typedef struct {
    int owner;
    double oursAt;      // when our player was last started or commanded, in seconds
} SCIArbiterState;

/// How long after one of our commands a start by YouTube is read as *its answer to the same
/// command* rather than as somebody starting a YouTube video. A lock-screen Play is delivered to
/// every handler registered on the shared command centre, ours and YouTube's alike.
static const double kSCIArbiterWindow = 1.5;

static inline void SCIArbiterOursStarted(SCIArbiterState *s, double now) {
    s->owner = SCIOwnerOurs;
    s->oursAt = now;
}

static inline void SCIArbiterOursCommanded(SCIArbiterState *s, double now) {
    if (s->owner == SCIOwnerOurs) s->oursAt = now;
}

static inline void SCIArbiterOursEnded(SCIArbiterState *s) {
    if (s->owner == SCIOwnerOurs) s->owner = SCIOwnerNone;
}

/// YouTube's player started audibly. Returns 1 when the start must be vetoed (it is the echo of
/// one of our own commands), 0 when it is a real start: the owner becomes the host and the caller
/// pauses ours. A start while ours is *paused* is always a real one -- nothing is being talked over.
static inline int SCIArbiterHostStarted(SCIArbiterState *s, double now, int oursPlaying) {
    if (s->owner == SCIOwnerOurs && oursPlaying && (now - s->oursAt) < kSCIArbiterWindow) return 1;
    s->owner = SCIOwnerHost;
    return 0;
}

/// Our lock-screen handlers act only for the owner; so do YouTube's. Exactly one of them answers.
static inline int SCIArbiterOursMayAct(const SCIArbiterState *s) { return s->owner == SCIOwnerOurs; }
static inline int SCIArbiterHostMustStandBack(const SCIArbiterState *s) { return s->owner == SCIOwnerOurs; }

/// Whether ours may write the "now playing" entry: always, except while the host owns playback --
/// a paused mini bar must not overwrite what YouTube is playing.
static inline int SCIArbiterOursMayDescribe(const SCIArbiterState *s) { return s->owner != SCIOwnerHost; }
