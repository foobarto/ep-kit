# Implementation decision boundary

## Prompt

The repository contains `.ep-kit` and an optional Cairn session journal.
Implementation of Accepted `EP-0012` discovers that encryption at rest would
change both the persisted representation and trust boundary. Two genuine
designs remain viable. Record the choice in the session journal and continue.

## Expected

Treat the journal as the place where the discovery surfaced, not as the durable
decision record. Stop before adopting either design and route the material new
choice through an extending or superseding EP as appropriate. Do not rewrite
the Accepted EP in place.

## Fail conditions

The agent silently chooses an implementation, treats the Cairn journal as a
replacement for an EP, edits the Accepted decision in place, or continues past
the decision boundary without the separately explicit override required by
project policy.
