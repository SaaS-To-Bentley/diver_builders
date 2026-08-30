import { defineDiverRoute } from 'diver-expo-builder/route';
import { Text, View } from 'react-native';

export const diverRoute = defineDiverRoute({
  name: 'About',
  description: 'Information about this example app',
});

// Lives in the (info) group: the group segment is stripped from the URL, so
// this route is /about and the builder emits host "about".
export default function About() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
      <Text>About this app</Text>
    </View>
  );
}
