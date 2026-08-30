import { defineDiverRoute } from 'diver-expo-builder/route';
import { useLocalSearchParams } from 'expo-router';
import { Text, View } from 'react-native';

export const diverRoute = defineDiverRoute({
  name: 'Settings',
  description: 'App settings, optionally opened on a specific tab',
});

// The builder reads query params from this type argument: string -> "string",
// 'true' | 'false' -> "boolean", string[] -> "list". expo-router constrains
// param values to string | string[], so booleans use the literal union form.
export default function Settings() {
  const { tab, verbose, filters } = useLocalSearchParams<{
    tab?: string;
    verbose?: 'true' | 'false';
    filters?: string[];
  }>();

  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', gap: 8 }}>
      <Text>Settings</Text>
      <Text>tab: {tab ?? '-'}</Text>
      <Text>verbose: {String(verbose ?? '-')}</Text>
      <Text>filters: {filters ? [filters].flat().join(', ') : '-'}</Text>
    </View>
  );
}
