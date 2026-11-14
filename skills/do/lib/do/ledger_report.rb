# frozen_string_literal: true

module Do
  # The ledger's fields in `preflight facts` output: the comment a later
  # edit goes through, its items as Checklist placed them, whether lines it
  # can't place make them unreliable, its gate lines, the first item this
  # run builds, and whether it records adopted criteria. No text of it is
  # printed.
  class LedgerReport
    def initialize(ledger)
      @ledger = ledger
    end

    def fields
      comment.merge(items: @ledger.placed_items.map { |item| item(item) }, boxes_ambiguous: !@ledger.ambiguous.empty?,
                    gates: @ledger.gates.map { |gate| { id: gate.id, state: gate.state } },
                    first_unbuilt: @ledger.first_unbuilt&.id, adopted_criteria: @ledger.adopted_criteria?)
    end

    private

    # comment_id is the REST id a later edit of the ledger goes through.
    def comment
      comment = @ledger.comment
      { comment_id: SkillSupport::Identifiers.comment_id!(comment.database_id), node_id: comment.id,
        author: comment.author.login }
    end

    def item(item)
      fields = { id: item.id, position: item.position, kind: item.kind, checked: item.checked }
      item.sub_issue ? fields.merge(sub_issue: item.sub_issue.id, state: item.sub_issue.state) : fields
    end
  end
end
