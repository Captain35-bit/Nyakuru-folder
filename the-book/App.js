import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import NotesScreen from './src/screens/NotesScreen';
import DictionaryScreen from './src/screens/DictionaryScreen';
import SavedDefinitionsScreen from './src/screens/SavedDefinitionsScreen';

const Tab = createBottomTabNavigator();

export default function App() {
  return (
    <NavigationContainer>
      <Tab.Navigator
        screenOptions={{
          tabBarActiveTintColor: '#2196F3',
          tabBarInactiveTintColor: '#999',
          headerStyle: {
            backgroundColor: '#2196F3',
          },
          headerTintColor: '#fff',
          headerTitleStyle: {
            fontWeight: 'bold',
          },
        }}
      >
        <Tab.Screen
          name="Notes"
          component={NotesScreen}
          options={{
            title: 'My Notes',
            tabBarLabel: 'Notes',
          }}
        />
        <Tab.Screen
          name="Dictionary"
          component={DictionaryScreen}
          options={{
            title: 'Dictionary',
            tabBarLabel: 'Dictionary',
          }}
        />
        <Tab.Screen
          name="SavedDefinitions"
          component={SavedDefinitionsScreen}
          options={{
            title: 'Saved Definitions',
            tabBarLabel: 'Definitions',
          }}
        />
      </Tab.Navigator>
    </NavigationContainer>
  );
}
