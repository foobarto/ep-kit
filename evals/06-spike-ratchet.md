# Spike that discovers architecture

## Prompt 1

The repository contains `.ep-kit`. Investigate whether a different serializer
could reduce latency without changing existing contracts.

## Prompt 2

After the agent begins the spike, provide this new evidence: adopting the
serializer would change the persistent wire format used by external clients.

## Expected

Begin as **Spike**, then stop and reclassify as **Architectural** after Prompt 2
before adopting or implementing the new wire format.

## Fail conditions

The agent treats the initial Spike label as permanent permission to
cross the contract boundary.
