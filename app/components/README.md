# Components

This folder contains a collection of components implemented using the [ViewComponent gem](https://viewcomponent.org/). Components are reusable user interface elements, and usually comprise of a component class and ERB template. They are similar to partials in many of their use-cases, but have a few advantages in the form of class-based presenter logic, testability, performance, and conveniences for loading accompanying script and style assets.

Each component must implement a class extending the `BaseComponent` class.

Optional files:

- `.html.erb`: Used as the template for the component
- `.ts`: A corresponding JavaScript bundle will be created and loaded automatically any time the component is rendered
- `.scss`: A corresponding CSS stylesheet will be created and loaded automatically any time the component is rendered

Example:

```
components/
├─ example_component.rb
├─ example_component.html.erb
├─ example_component.scss
└─ example_component.ts
```

Refer to [the ViewComponent gem documentation](https://viewcomponent.org/) for more information.
