require 'test_helper'

class FakeClass
  def age
    25
  end

  def self.hello_world
    'hello world'
  end

  def self.repeat(arg)
    arg
  end

  def self.multi_args(*args)
  end
end

class SpyTest < Minitest::Spec
  describe Spy do
    after { Spy.restore :all }

    describe 'on_any_instance' do
      it 'allows you to spy on instances of a class' do
        spy = Spy.on_any_instance(FakeClass, :age)
        instance_a = FakeClass.new
        instance_a.age
        assert spy.call_count == 1
        instance_b = FakeClass.new
        instance_b.age
        assert spy.call_count == 2
      end

      it 'can spy on instances that have already been initialized' do
        instance = FakeClass.new
        spy = Spy.on_any_instance(FakeClass, :age)
        instance.age
        assert spy.call_count == 1
      end

      it 'throws if the instance method is already being spied' do
        Spy.on_any_instance(FakeClass, :age)
        assert_raises Spy::Errors::AlreadySpiedError do
          Spy.on_any_instance(FakeClass, :age)
        end
      end
    end

    describe '.on' do
      describe 'with no arguments' do
        it 'throws an ArgumentError' do
          assert_raises ArgumentError do
            Spy.on
          end
        end
      end

      describe 'with one argument' do
        it 'throws an ArgumentError' do
          assert_raises ArgumentError do
            Spy.on Array
          end
        end
      end

      it 'modifies the original method of an object' do
        obj = FakeClass.new
        old_method = obj.method(:age)
        Spy.on(obj, :age)
        assert obj.method(:age) != old_method
      end

      it 'modifies the class method of a class' do
        klass = FakeClass
        old_method = FakeClass.method(:hello_world)
        Spy.on(FakeClass, :hello_world)
        assert FakeClass.method(:hello_world) != old_method
      end

      it 'should not modify the spied methods return value' do
        Spy.on(FakeClass, :hello_world)
        assert FakeClass.hello_world == 'hello world'

        instance = FakeClass.new
        Spy.on(instance, :age)
        assert instance.age == 25
      end

      it 'throws if the object is missing the method to spy on' do
        assert_raises NameError do
          Spy.on(FakeClass, :this_does_not_exist)
        end
      end

      it 'throws if the method is already being spied' do
        Spy.on(FakeClass, :hello_world)
        assert_raises Spy::Errors::AlreadySpiedError do
          Spy.on(FakeClass, :hello_world)
        end
      end

      it 'returns a Spy instance' do
        assert Spy.on(FakeClass, :hello_world).is_a? Spy::Instance
      end

      it 'allows you to spy on multiple methods on the same object' do
        spy_a = Spy.on(FakeClass, :hello_world)
        spy_b = Spy.on(FakeClass, :repeat)
        FakeClass.hello_world
        assert spy_a.call_count == 1
        assert spy_b.call_count == 0
        FakeClass.repeat('test')
        assert spy_a.call_count == 1
        assert spy_b.call_count == 1
      end

      it 'leaves the method with the same visibility it had previously' do
        klass = Class.new(Object) do
          private

          def hello
            'hello'
          end
        end

        obj = klass.new
        assert obj.class.private_method_defined?(:hello)
        Spy.on(obj, :hello)
        assert obj.class.private_method_defined?(:hello)
      end
    end

    describe '.restore' do
      it 'restores all of the spied methods with the :all argument' do
        obj = FakeClass.new
        obj_method = obj.method(:age)
        klass = FakeClass
        klass_method = klass.method(:hello_world)

        Spy.on(obj, :age)
        Spy.on(klass, :hello_world)

        Spy.restore(:all)

        assert obj.method(:age) == obj_method
        assert klass.method(:hello_world) == klass_method
      end

      it 'restores the originally spied method of an object' do
        obj = FakeClass.new
        obj_method = obj.method(:age)

        Spy.on(obj, :age)

        Spy.restore(obj, :age)

        assert obj.method(:age) == obj_method
      end

      it 'throws if the method is not being spied' do
        obj = FakeClass.new
        assert_raises Spy::Errors::MethodNotSpiedError do
          Spy.restore(obj, :age)
        end
      end
    end

    describe '.with_args' do
      it 'should only count times when the args match' do
        spy = Spy.on(FakeClass, :repeat).with_args('hello')
        assert spy.call_count == 0
        FakeClass.repeat 'yo'
        assert spy.call_count == 0
        FakeClass.repeat 'hello'
        assert spy.call_count == 1
        FakeClass.repeat 'yo'
        assert spy.call_count == 1
        FakeClass.repeat 'hello'
        assert spy.call_count == 2
      end

      it 'should allow tracking of multiple arg sets' do
        skip
        spy_a = Spy.on(FakeClass, :repeat).with_args('hello')
        spy_b = Spy.on(FakeClass, :repeat).with_args('goodbye')
        FakeClass.repeat 'hello'
        assert spy_a.call_count == 1
        assert spy_b.call_count == 0
        FakeClass.repeat 'goodbye'
        assert spy_a.call_count == 1
        assert spy_b.call_count == 1
      end
    end

    describe '.call_count' do
      it 'should initially be zero' do
        spy = Spy.on(FakeClass, :hello_world)
        assert spy.call_count == 0
      end

      it 'should properly increment' do
        spy = Spy.on(FakeClass, :hello_world)
        FakeClass.hello_world
        assert spy.call_count == 1
        FakeClass.hello_world
        assert spy.call_count == 2
      end
    end

    describe '.when' do
      it 'only increments call count if the filter returns true' do
        tracking = false
        spy = Spy.on(FakeClass, :hello_world).when { tracking == true }
        FakeClass.hello_world
        assert spy.call_count == 0
        tracking = true
        FakeClass.hello_world
        assert spy.call_count == 1
      end

      it 'passes all of the call arguments to the block' do
        arg_count = 0
        Spy.on(FakeClass, :multi_args).when {|*args| arg_count = args.size}
        FakeClass.multi_args(1, 2, 3)
        assert arg_count == 3
      end

      it 'allows the user to only capture some args' do
        sum = 0
        Spy.on(FakeClass, :multi_args).when {|one, two| sum = one + two}
        FakeClass.multi_args(1, 2, 3)
        assert sum == 3
      end
    end

    describe '.then' do
      it 'calls it when the method passes all spy conditions' do
        skip
      end
    end
  end
end
