# Sing evidence

Status: blocked. No Sing UI, model, downloader, or audio hook is present.

## S01 — distributable model

No candidate has supplied all of the required provenance: redistribution permission,
immutable source URL, SHA-256, exact byte size, conversion recipe, iOS runtime,
supported OS/device range, and measured CPU, GPU, memory, and latency budget.
Without those facts, Prisma cannot ship or advertise a vocal-reduction model.

A future evidence packet must reproduce the artifact hash and measurements on each
claimed device before S03 can begin. Do not add a placeholder control meanwhile.

## S02 — Spotify streamed-source contract

The inspected target is the decrypted Spotify 9.1.78 executable with UUID
`C712370B-44CD-35C8-A058-4FBED1AD0758` and `cryptid = 0`. This checkout does not
contain its ignored local extraction under `out/parity-evidence/`, a recorded
streamed-source tree, or runtime traces. Therefore it has no reproducible proof of
the source queue layout, callback signatures, ownership, buffer lifetime, or its
seek and track-transition behavior. Objective-C metadata and Prisma's output-side
AudioUnit integration do not establish those opaque source-side contracts.

Before selecting an interception point, supply the local binary/tree paths and UUID
check, every offset and call signature, and traces for start, buffering, seek,
A-to-B-to-A, stop, and disposal. The traces must establish who owns each buffer and
when it remains valid.
