import 'initial_state_test.dart' as initial_state_test;
import 'initial_value_callback_test.dart' as initial_value_callback_test;
import 'key_update_test.dart' as key_update_test;
import 'key_error_test.dart' as key_error_test;
import 'reload_test.dart' as reload_test;
import 'value_test.dart' as value_test;
import 'value_update_test.dart' as value_update_test;
import 'error_update_test.dart' as error_update_test;
import 'truth_source_update_test.dart' as truth_source_update_test;
import 'resource_action_test.dart' as resource_action_test;

void main() {
  initial_state_test.main();
  initial_value_callback_test.main();
  key_update_test.main();
  key_error_test.main();
  reload_test.main();
  value_test.main();
  value_update_test.main();
  error_update_test.main();
  truth_source_update_test.main();
  resource_action_test.main();
}
