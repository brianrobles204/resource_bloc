## 0.1.0-dev.1 - 0.1.0-dev.6

- Initial release of Resource Bloc
  - A specialized Bloc for managing data backed by both local and remote sources.
  - `BaseResourceBloc` provides the base functionality for resource blocs
  - `ResourceBloc` provides additional features such as `.reload()`, key setters, and other non-core functionality.
- ### 0.1.0-dev.6

  - Added SnapshotState as super type of ResourceState. The snapshot doesn't include the `key` since this is more of a detail for resource blocs.