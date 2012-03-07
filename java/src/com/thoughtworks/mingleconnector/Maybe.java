// Copyright 2011 ThoughtWorks, Inc.
// 
// Licensed under the Apache License, Version 2.0 (the "License"); you
// may not use this file except in compliance with the License. You may
// obtain a copy of the License at
// 
// http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
// implied. See the License for the specific language governing
// permissions and limitations under the License.
// 
package com.thoughtworks.mingleconnector;

public abstract class Maybe<T> {
    private Maybe() { }

    public abstract void ifValue(Action a);
    public abstract void ifValue(Action ifAction, NullaryAction elseAction);
    public abstract T force();
    public abstract T force(T theDefault);
    public abstract T force(RuntimeException e);

    public static <T> Maybe<T> fromNullable(T t) {
        return fromNullable(t, new Function.Identity<T>());
    }
    public static <S, T> Maybe<T> fromNullable(S s, Function<S, T> f) {
        if (s == null) return nothing();
        return definitely(f.call(s));
    }
    public static <T> Maybe<T> definitely(T t) { return new Definitely(t); }
    public static <T> Maybe<T> nothing() { return new Nothing<T>(); }

    public static class NoValue extends RuntimeException { }

    private static class Definitely<T> extends Maybe<T> {
        private final T value;
        public Definitely(T value) {
            if (value == null ) throw new NullPointerException();
            this.value = value;
        }

        public void ifValue(Action a) { a.call(value); }
        public void ifValue(Action ifAction, NullaryAction elseAction) { ifAction.call(value); }
        public T force() { return value; }
        public T force(RuntimeException e) { return force(); }
        public T force(T theDefault) { return force(); }
    }

    private static class Nothing<T> extends Maybe<T> {
        public void ifValue(Action a) { }
        public void ifValue(Action ifAction, NullaryAction elseAction) { elseAction.call(); }
        public T force() { throw new NoValue(); }
        public T force(RuntimeException e) { throw e; }
        public T force(T theDefault) { return theDefault; }
    }
}
