## 0.1.0-dev.1

- Initial release of MobX Resource Bloc
  - Create resource blocs whose properties work within MobX's reactivity system.
  - `ComputedResourceBloc` will recompute its key any time an observed value changes.
  - Resource bloc properties such as `stream` and `state` are observable values themselves and will update any observing MobX reactions.
