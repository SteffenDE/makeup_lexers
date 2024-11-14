## JavaScript Code Example

```javascript
#!/usr/bin/env node
// This is a single-line comment

/* This is a multi-line comment
   showing various JavaScript features */

// Numbers
const integers = 42;
const float = 3.14159;
const hex = 0xFF;
const binary = 0b1010;
const octal = 0o777;
const bigInt = 9007199254740991n;
const scientific = 1.23e-4;

// Strings
const singleQuoted = 'Hello World';
const doubleQuoted = "Hello World";
const escapedString = 'It\'s a beautiful day\nNew line\tTabbed';
const templateLiteral = `Current value: ${integers + float + {}}
  Multi-line string
  With interpolation: ${hex}`;

// Symbols
const symbol = Symbol('description');
const uniqueSymbol = Symbol.for('global');

// Arrays and destructuring
const array = [1, 2, 3, 'mixed', true, null];
const [first, second, ...rest] = array;
const matrix = [[1, 2], [3, 4]];

// Objects and destructuring
const person = {
  name: 'John',
  age: 30,
  'special-key': true,
  method() {
    return this.name;
  },
  get fullName() {
    return `${this.name} Doe`;
  },
  set fullName(value) {
    this.name = value;
  }
};

const { name, age: personAge } = person;

// Classes
class Animal {
  #privateField = 'hidden';
  static species = 'Unknown';

  constructor(name) {
    this.name = name;
  }

  static createDog() {
    return new this('Dog');
  }

  makeSound() {
    console.log('Generic animal sound');
  }
}

class Dog extends Animal {
  constructor(name, breed) {
    super(name);
    this.breed = breed;
  }

  makeSound() {
    console.log('Woof!');
  }
}

// Functions
function normalFunction(a, b = 1) {
  return a + b;
}

const arrowFunction = (x, y) => {
  return x * y;
};

const shortArrow = x => x * 2;

async function asyncFunction() {
  try {
    const response = await fetch('https://api.example.com');
    const data = await response.json();
    return data;
  } catch (error) {
    console.error(error);
    throw new Error('Failed to fetch');
  }
}

// Control structures
if (array.length > 0) {
  console.log('Array has elements');
} else if (array.length === 0) {
  console.log('Array is empty');
} else {
  console.log('Impossible condition');
}

for (let i = 0; i < array.length; i++) {
  if (i === 1) continue;
  if (i === 4) break;
  console.log(array[i]);
}

for (const item of array) {
  console.log(item);
}

for (const key in person) {
  console.log(key, person[key]);
}

while (false) {
  console.log('Never reached');
}

do {
  console.log('Executed once');
} while (false);

switch (typeof person) {
  case 'object':
    console.log('It\'s an object');
    break;
  case 'string':
    console.log('It\'s a string');
    break;
  default:
    console.log('Unknown type');
}

// Regular expressions
const regex = /^hello\s+world$/i;
const regexObj = new RegExp('pattern', 'g');

// Built-in objects and methods
const now = new Date();
const map = new Map([['key', 'value']]);
const set = new Set([1, 2, 3]);
const weakMap = new WeakMap();
const int32Array = new Int32Array(5);

// Promises and async/await
const promise = new Promise((resolve, reject) => {
  setTimeout(() => {
    if (Math.random() > 0.5) {
      resolve('Success!');
    } else {
      reject(new Error('Failed!'));
    }
  }, 1000);
});

promise
  .then(result => console.log(result))
  .catch(error => console.error(error))
  .finally(() => console.log('Cleanup'));

// Modules
export const exported = 'I am exported';
export default class MainClass {}
export { person, Animal };

// Nullish coalescing and optional chaining
const nullish = null ?? 'default';
const chainedValue = person?.address?.street;

// Logical operators and assignments
const logicalAnd = true && 'value';
const logicalOr = false || 'fallback';
let value = 0;
value &&= 5;
value ||= 10;
value ??= 15;

// Bitwise operations
const bitwiseAnd = 5 & 3;
const bitwiseOr = 5 | 3;
const bitwiseXor = 5 ^ 3;
const leftShift = 5 << 1;
const rightShift = 5 >> 1;
const zeroFillRightShift = -5 >>> 1;

// DOM manipulation (if in browser)
if (typeof window !== 'undefined') {
  const element = document.getElementById('example');
  element?.addEventListener('click', (event) => {
    event.preventDefault();
    element.innerHTML = `Clicked at ${event.clientX}, ${event.clientY}`;
  });
}
```
