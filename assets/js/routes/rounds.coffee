define ['team', 'judge', 'round', 'util', 'alertcontroller'], (Team, Judge, Round, Util, AlertController) ->
  (ui, $routeProvider) ->
    $routeProvider.when '/rounds/:roundIndex',
      templateUrl: 'partials/rounds.html'
      controller: [ '$scope', '$routeParams', '$compile', ($scope, $routeParams, $compile) ->
        index = $routeParams.roundIndex - 1
        round = $scope.round = $scope.tournament.rounds[index]
        $scope.ranks = Judge.ranks
        $scope.rankStrings = Judge.rankStrings
        $scope.ballotsPerMatchOptions = [1, 3, 5, 7, 9]
        $scope.infinity = 10000
        $scope.maxPanelChoices = [$scope.infinity, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        $scope.infinityName = (o, inf, name) -> if o == inf then name else o
        $scope.priorityChoices = [0, 1]
        $scope.priorityChoiceNames = ["Assign good judges to good teams", "Assign good judges to weak teams"]
        $scope.orderChoices = [0, 1]
        $scope.orderChoiceNames = ["Assign judges to good teams first", "Assign judges to weak teams first"]

        Util.installScopeUtils $scope

        _tf = $scope.truncFloat
        $scope.truncFloatN = (v, prec) ->
          if typeof v == 'number'
            _tf v, prec
          else
            v

        for judge in round.judges
          ((judge) ->
            $scope.$watch ->
              ropts = judge.rounds[round.id]
              if ropts?
                ropts.participates
              else
                null
            , (v, o) ->
              return if not v?
              return if v == o
              if v
                round.freeJudges.push judge
              else
                ropts = judge.rounds[round.id]
                if ropts? and ropts.ballot and not ropts.ballot.locked
                  if ropts.shadow
                    Util.arrayRemove ropts.ballot.shadows, judge
                  else
                    Util.arrayRemove ropts.ballot.judges, judge
                  ropts.ballot = null
                else
                  Util.arrayRemove round.freeJudges, judge
              return
          ) (judge)


        for room in round.rooms
          ((room) ->
            $scope.$watch ->
              ropts = room.rounds[round.id]
              if ropts?
                ropts.participates
              else
                null
            , (v, o) ->
              return if not v?
              return if v == o
              if v
                round.freeRooms.push room
              else
                ropts = room.rounds[round.id]
                if ropts? and ropts.ballot
                  ropts.ballot.room = null
                  ropts.ballot = null
                else
                  Util.arrayRemove round.freeRooms, room
              return
          ) (room)

        $scope.addAllTeams = ->
          for team in $scope.tournament.teams
            team.rounds[round.id].participates = true

        $scope.removeAllTeams = ->
          for team in $scope.tournament.teams
            team.rounds[round.id].participates = false

        $scope.addAllJudges= ->
          for judge in $scope.tournament.judges
            ropts = judge.rounds[round.id]
            continue if ropts.ballot? and ropts.ballot.locked
            ropts.participates = true

        $scope.removeAllJudges = ->
          for judge in $scope.tournament.judges
            ropts = judge.rounds[round.id]
            continue if ropts.ballot? and ropts.ballot.locked
            ropts.participates = false

        $scope.removeShadows = ->
          for judge in $scope.tournament.judges
            if judge.rank == Judge.shadowRank
              ropts = judge.rounds[round.id]
              continue if ropts.ballot? and ropts.ballot.locked
              ropts.participates = false

        $scope.addAllRooms= ->
          for room in $scope.tournament.rooms
            room.rounds[round.id].participates = true

        $scope.removeAllRooms = ->
          for room in $scope.tournament.rooms
            room.rounds[round.id].participates = false

        $scope.sortByRank = ->
          round.sortByRank round.teams

        $scope.shuffleRooms = ->
          round.shuffleRooms()

        $scope.judgeUd = (ballot, shadow) ->
          {ballot: ballot, shadow: shadow}

        $scope.judgeGroupTest = (fromList, toList) ->
          ballot = toList.ud.ballot
          return true if  not ballot?
          return true if fromList == toList
          return false if ballot.locked or not ballot.teams[0] or not ballot.teams[1]
          toList.ud.shadow or ballot.judges.length < round.ballotsPerMatchSolved()

        $scope.judgeMove = (fromList, fromIndex, toList, toIndex) ->
          if fromList == toList and toIndex > fromIndex
            toIndex--
          el = fromList.model.splice(fromIndex, 1)[0]
          toList.model.splice toIndex, 0, el
          opts = el.rounds[round.id]
          opts.ballot = toList.ud.ballot
          opts.shadow = toList.ud.shadow

        updateDecimals = (scores) ->
          $scope.scoreDecimals ?= 0
          sd = $scope.scoreDecimals

          maxScoreDec = (s) ->
            d1 = Util.decimalsOf s[0], 2
            d2 = Util.decimalsOf s[1], 2
            if d2 > d1
              d2
            else
              d1

          shouldUpdate = true
          shouldSearch = true
          if scores
            d = maxScoreDec scores
            if d == sd
              shouldUpdate = false
              shouldSearch = false
            else if d > sd
              $scope.scoreDecimals = sd = d
              shouldSearch = false

          if shouldSearch
            max = 0
            for ballot in round.ballots
              rs = ballot.stats.rawScores
              continue if not rs?
              d = maxScoreDec rs
              if d > max
                max = d
            if sd == max
              shouldUpdate = false
            else
              $scope.scoreDecimals = sd = max

          if shouldUpdate
            for ballot in round.ballots
              st = ballot.stats
              continue if not st.rawScores?
              st.scores = [st.rawScores[0].toFixed(sd), st.rawScores[1].toFixed(sd)]

        updateStats = (ballot, dec = true) ->
          pres0 = ballot.teams[0]? and ballot.presence[0]
          pres1 = ballot.teams[1]? and ballot.presence[1]
          if not pres0 and not pres1
            ballot.stats =
              scores: ['not played', '']
              winClass: 'hidden-true'
              classes: ['', 'hidden-true']
          else if not pres0 or not pres1
            ballot.stats =
              scores: ['default win', '']
              winClass: 'hidden-true'
              classes: [(if pres0 then 'prop' else 'opp'), 'hidden-true']
          else if ballot.locked
            s = [0, 0]
            w = [0, 0]
            for side in [0..1]
              ballots = 0
              for vote in ballot.votes
                for i in [0...4]
                  s[side] += vote.scores[side][i] * vote.ballots
                w[side] += if side then vote.opp else vote.prop
                ballots += vote.ballots
              s[side] /= ballots

            dc = $scope.scoreDecimals
            ballot.stats =
              scores: [s[0].toFixed(dc), s[1].toFixed(dc)]
              rawScores: s
              winClass: if w[0]>w[1] then 'prop' else 'opp'
              classes: ['', '']

            updateDecimals(s) if dec
          else
            ballot.stats =
              scores: ['unfilled', '']
              winClass: 'hidden-true'
              classes: ['muted-true', '']
          return

        for b in round.ballots
          updateStats b, false
        updateDecimals()

        $scope.assignJudges = ->
          round.assignJudges()

        $scope.assignRooms = ->
          round.assignRooms()

        $scope.pair = ->
          $scope.pairOpts =
            algorithm: 0
            sides: 0
            manualSides: true
            shuffleRooms: true
            hardSides: true
            minimizeReMeet: true
            matchesPerBracket: round.tournament.matchesPerBracket
            evenBrackets: round.tournament.evenBrackets
          prev = $scope.prevRounds = round.previousRounds()
          $scope.pairAlgorithms = if prev.length then Round.allAlgos else Round.initialAlgos
          $scope.algoName = Round.algoName
          $scope.pairingTeams = round.pairingTeams()
          $scope.manualPairing = []
          v = $scope.sides = [0, 1]
          for r in prev
            name = r.getName()
            v.push
              roundId: r.id
              name: "Same as " + name
              flip: false
            v.push
              roundId: r.id
              name: "Opposite from " + name
              flip: true

          $scope.sidesName = (s) ->
            if s == 0
              return "Random"
            if s == 1
              return "Balanced"
            return s.name

          new AlertController
            buttons: ['Cancel', 'Ok']
            cancelButtonIndex: 0
            title: 'Round '+(index+1)+' pairing'
            htmlMessage: $compile(templates.pairModal())($scope)
            onClick: (alert, button) ->
              if button == 1
                opts = $scope.pairOpts
                if opts.algorithm == 1
                  if $scope.pairingTeams.length
                    alert.find('.error-placeholder').html templates.errorAlert
                      error: 'You must pair all the teams before continuing'
                    return
                  opts.manualPairing = $scope.manualPairing
                alert.modal 'hide'
                Util.safeApply $scope, ->
                  round.pair opts
                  for b in round.ballots
                    updateStats b

        $scope.addTeamToManualPairing = (team, index) ->
          if $scope.incompletePairing
            p = $scope.incompletePairing
            $scope.incompletePairing = null
            if not p.prop
              p.prop = team
            else if not p.opp
              p.opp = team
            else
              return
          else
            p = $scope.incompletePairing = { prop: team }
            $scope.manualPairing.push p
            div = $('.manual-pairings .span8')
            div.animate
              scrollTop: div[0].scrollHeight
            , 500

          $scope.pairingTeams.splice index, 1

        $scope.removePairFromManualPairing = (pair, index) ->
          if pair.prop
            if pair.opp
              $scope.pairingTeams.splice 0, 0, pair.prop, pair.opp
            else
              $scope.pairingTeams.splice 0, 0, pair.prop
          else
            $scope.pairingTeams.splice 0, 0, pair.opp
          $scope.manualPairing.splice index, 1
          if pair == $scope.incompletePairing
            $scope.incompletePairing = null

        $scope.reverseSidesInManualPairing = (pairing) ->
          p = pairing.prop
          pairing.prop = pairing.opp
          pairing.opp = p

        $scope.editBallot = (index) ->
          sc = $scope.$new()
          ballot = round.ballots[index]
          return if not ballot.teams[0]? or not ballot.teams[1]?
          noBallots = round.ballotsPerMatchSolved()
          sc.votes = ballot.getVotesForBallots noBallots
          sc.speakers = [ballot.teams[0].players, ballot.teams[1].players]
          n = sc.votes.length

          sc.winner = (vote) ->
            if vote.prop > vote.opp
              "prop"
            else
              "opp"

          sc.roles = ballot.getSpeakerRoles()
          sc.presence = [ballot.presence[0], ballot.presence[1]]
          sc.sides = ['Prop', 'Opp']
          sc.sidesClass = ['prop', 'opp']
          sc.validPlayer = (el, v) ->
            c = 0
            for i in [0..2]
              c++ if v[i] == el
            return c

          splitsForBallots = (nb) ->
            [_.range((nb/2>>0)+1, nb+1), _.range((nb/2>>0)+(nb&1))]

          noBallots = 0
          for i in [0...n]
            ((i) ->
              vote = sc.votes[i]
              nb = vote.ballots
              noBallots += nb
              if not vote.judge and not ballot.locked
                sc.noJudgesWarning = true
              vote.aux =
                decisionValid: true
                validSplits: splitsForBallots nb
                winner: 0

              sc.$watch (-> vote.prop), (v) ->
                vote.opp = vote.ballots - vote.prop
              sc.$watch (-> vote.opp), (v) ->
                vote.prop = vote.ballots - vote.opp
                
              sc.$watch (-> pointsWinner vote), (v) ->
                vote.aux.decisionValid = true
                if vote.prop > vote.opp
                  win = vote.prop
                  loss = vote.opp
                else
                  win = vote.opp
                  loss = vote.prop
                if v == 0
                  vote.prop = win
                  vote.opp = loss
                  vote.aux.winner = 0
                else if v == 1
                  vote.prop = loss
                  vote.opp = win
                  vote.aux.winner = 1
                else
                  vote.aux.decisionValid = false
            ) i

          sc.lockJudgesInfo = not ballot.locked and not sc.noJudgesWarning

          if n > 1
            sc.votes.push total =
              judge:
                name: "Total"
              scores: [[70, 70, 70, 35], [70, 70, 70, 35]]
              total: true
              aux:
                decisionValid: true
                validSplits: splitsForBallots noBallots
                winner: 0
            for i in [0...2]
              for j in [0...4]
                ((i, j) ->
                  sc.$watch ->
                    s = 0
                    for vote in sc.votes
                      if not vote.total
                        s += vote.scores[i][j] * vote.ballots
                    s / noBallots
                  , (v) -> total.scores[i][j] = v
                ) i, j

            sc.$watch ->
              s = 0
              for vote in sc.votes
                if not vote.total
                  s += vote.prop
              s
            , (v) -> total.prop = v

            sc.$watch ->
              s = 0
              for vote in sc.votes
                if not vote.total
                  s += vote.opp
              s
            , (v) -> total.opp = v

            sc.$watch ->
              for k in [0...n]
                if not sc.votes[k].aux.decisionValid
                  return false
              return true
            , (v) -> sc.votes[n].aux.decisionValid = v

          pointsWinner = (vote) ->
            scp = vote.scores[0]
            sco = vote.scores[1]
            tp = scp[0] + scp[1] + scp[2] + scp[3]
            to = sco[0] + sco[1] + sco[2] + sco[3]
            if tp > to
              0
            else if tp < to
              1
            else
              2

          new AlertController
            buttons: ['Cancel', 'Ok']
            cancelButtonIndex: 0
            width: 700
            title: '<span class="prop">'+ballot.teams[0].name+'</span><span> vs. </span><span class="opp">'+ballot.teams[1].name+'</span>'
            htmlMessage: $compile(templates.ballotSheet())(sc)
            onClick: (alert, button) ->
              sc.$apply ->
                sc.drawsError = false
                sc.outOfRangeError = false
              voteError = false
              pres = sc.presence[0] and sc.presence[1]
              if button == 1
                for vote in sc.votes
                  continue if vote.total
                  for i in [0..1]
                    for j in [0..2]
                      nr = vote.scores[i][j]
                      if nr < 60 or nr > 80
                        voteError = true
                        if pres
                          sc.$apply -> sc.outOfRangeError = true
                          return
                    nr = vote.scores[i][3]
                    if nr < 30 or nr > 40
                      voteError = true
                      if pres
                        sc.$apply -> sc.outOfRangeError = true
                        return
                  if not vote.aux.decisionValid
                    voteError = true
                    if pres
                      sc.$apply -> sc.drawsError = true
                      return
                if not voteError
                  ballot.votes = _.filter sc.votes, (x) -> !x.total
                ballot.roles = [sc.roles[0].roles, sc.roles[1].roles]
                ballot.presence = [sc.presence[0], sc.presence[1]]
                sc.$destroy()
                sc = null

                for vote in ballot.votes
                  delete vote.aux
                ballot.locked = true

                $scope.$apply ->
                  updateStats ballot
                alert.modal 'hide'
            onDismissed: (alert) ->
              sc.$destroy() if sc?

      ]
