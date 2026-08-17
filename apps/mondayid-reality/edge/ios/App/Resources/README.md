# Alert-zone registry

`oref-cities.json` is generated at build time by `edge/ios/sync-zone-registry.sh` from the MIT-licensed `eladnava/pikud-haoref-api` city metadata snapshot.

It is treated as metadata, not authority. The build fails closed if the registry is too small, structurally incomplete, has duplicate IDs, or does not contain control zones. Alert authority remains the observed official-origin Home Front Command feed; this registry only maps a user's multilingual zone selection to the Hebrew alert-zone identity used by that feed.

Personal selections are stored on-device as zone IDs. They are not sent to the cloud cognition surface.
