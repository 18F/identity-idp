import React from 'react';
import ReactDOM from 'react-dom';

const div = document.getElementById('app');

class App extends React.Component {
  render () {
    return (
      <div>
        <h1>Hello!</h1>
      </div>
    );
  }
}

ReactDOM.render(<App />, div);
