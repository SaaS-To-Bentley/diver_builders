import { defineDiverRoute } from 'diver-expo-builder/route';
import { Text, View } from 'react-native';

export const diverRoute = defineDiverRoute({
  name: 'Profile',
  description: 'The current user profile screen',
});

export default function Profile() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
      <Text>Profile</Text>
    </View>
  );
}
