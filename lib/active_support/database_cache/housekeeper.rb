module ActiveSupport
  module DatabaseCache
    class Housekeeper
      DeleteTask = Struct.new(:count)
      TouchTask = Struct.new(:ids)
      HaltTask = Class.new

      attr_reader :task_queue, :housekeeping_thread, :delete_by, :delete_age, :touch_batch_size, :delete_batch_size, :writing_role

      def initialize(delete_by: :updated_at, delete_age: 2.weeks, touch_batch_size: 10, delete_batch_size: 10, writing_role: nil)
        @task_queue = SizedQueue.new(1000)
        @delete_by = delete_by
        @delete_age = delete_age
        @touch_batch_size = touch_batch_size
        @delete_batch_size = delete_batch_size
        @writing_role = writing_role
        @housekeeping_thread = Thread.new { run_loop }
      end

      def touch_later(entry_ids:)
        task_queue.push(TouchTask.new(entry_ids), true)
      rescue ThreadError
        false
      end

      def delete_later(count:)
        task_queue.push(DeleteTask.new(count), true)
      rescue ThreadError
        false
      end

      def stop(timeout: 0)
        task_queue.push(HaltTask.new)
        housekeeping_thread.join(timeout)
      end

      private
        def run_loop
          delete_count = 0
          touch_ids = []

          loop do
            task = task_queue.pop
            case task
            when DeleteTask
              delete_count += task.count
            when TouchTask
              touch_ids.concat(task.ids)
            when HaltTask
              break
            end

            delete_count -= delete_records(delete_count) if delete_count >= delete_batch_size
            touch_records(touch_ids) if touch_ids.size >= touch_batch_size
          end
        end

        def delete_records(delete_count)
          total_deleted = 0
          loop do
            deleted = with_writing_role do
              Entry.delete_some(delete_batch_size, delete_by: :updated_at, delete_age: 2.weeks)
            end

            if deleted < delete_batch_size
              # indicates there were fewer records available for deletion than the batch size,
              # so let's reset the deletion counter
              return delete_count
            else
              total_deleted += deleted
              return total_deleted if (delete_count - total_deleted) < delete_batch_size
            end
          end
        end

        def touch_records(touch_ids)
          while touch_ids.size >= touch_batch_size do
            with_writing_role { Entry.touch(touch_ids.shift(touch_batch_size)) }
          end
        end

        def with_writing_role
          if writing_role
            DatabaseCache::ApplicationRecord.connected_to(role: writing_role) { yield }
          else
            yield
          end
        end
    end
  end
end
