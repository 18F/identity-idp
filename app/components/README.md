# Components

This folder contains a collection of components implemented using the [ViewComponent gem](https://viewcomponent.org/). Components are reusable user interface elements, and usually comprise of a component class and ERB template. They are similar to partials in many of their use-cases, but have a few advantages in the form of class-based presenter logic, testability, performance, and conveniences for loading JavaScript assets.

Each component must implement a class extending the `BaseComponent` class. If an accompanying `.html.erb` file exists, it will be used as the template for that component. Similarly, if an `.ts` or `.tsx` file exists, the bundle generated from that JavaScript will be loaded automatically any time the component is rendered.

```
components/
├─ example_component.rb
├─ example_component.html.erb
└─ example_component.ts
```

Refer to [the ViewComponent gem documentation](https://viewcomponent.org/) for more information.
