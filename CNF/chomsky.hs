import Data.List

type Symbol = [Char] --a whole string can represent a single symbol
type WorD = [Symbol]
type Rule = (Symbol,[WorD]) --only 2nd type grammar is appropriate /// must give all right hand sides for a rule
type Rule' = (Symbol, WorD) --we will have to break down each rule into rules like this (S -> [["a"],["b"]]   ==>   [S -> ["a"]  ,  S -> ["b"]])
type Grammar = (Symbol, Symbol, [Symbol], [Symbol], [Rule]) --(S, epsilon, N, T, R)


--------------------------------------------------------------------------------GRAMMAR REDUCTION-------------------------------------------------------------------------------------

finD :: (a -> Bool) -> [a] -> a
finD _ [] = error "finD: No such element"
finD beta list@(x:xs)
   | beta x = x
   | otherwise = finD beta xs

--should be called by passing the start symbol
getReachables :: Grammar -> [Symbol] -> [Symbol] -> [Symbol]
getReachables _ checkedSet [] = checkedSet
getReachables grammar checkedSet currentSet@(x:xs) = getReachables grammar (x:checkedSet) (xs ++ newNts)
   where 
   nts = concat $ snd $ finD (\(lhs, _) -> lhs == x) rules   --it merges the right hand sides, but still keeps each Symbol separted (as individual elements in the list)
   newNts = [ nt | nt <- nts, not (nt `elem` currentSet) && not (nt `elem` checkedSet) && nt `elem` nonterminals]
   (start, eps, nonterminals, terminals, rules) = grammar

--Global helper function
isSubsetOf :: Eq a => [a] -> [a] -> Bool
[] `isSubsetOf` other = True
(x:xs) `isSubsetOf` other = x `elem` other && xs `isSubsetOf` other

--should be called with empty list   
getProductives :: Grammar -> [Symbol] -> [Symbol]
getProductives grammar currentSet
    | currentSet == newSet = currentSet --this may produce errors in a case where the two lists contain the same items, but in different order (can be solved by mutual containment) /// it probably won't since the map function will always preserve the order of the left-hand sides
    | otherwise = getProductives grammar newSet
    where
    newSet = map fst (filter (\(lhs,rhs) -> any (\x -> x `isSubsetOf` (currentSet ++ terminals)) rhs) rules) --gets the lhs of each rule that has at least one rhs (a subrule) that is a subset of the currentSet and the terminals
    (start, eps, nonterminals, terminals, rules) = grammar

getUsefuls :: Grammar -> [Symbol]
getUsefuls grammar = intersect (getReachables grammar [] [start]) (getProductives grammar [])
    where
    (start, eps, nonterminals, terminals, rules) = grammar

reduceGrammar :: Grammar -> Grammar
reduceGrammar grammar = (start, eps, nonterminals, terminals, newRules)
    where
    newRules = filter (\r -> not $ null $ snd r) (map (filterRhs) filteredRules) --filters those rules that have a useful lhs (whether their filtered rhs is not null)
    filterRhs (lhs,rhs) = (lhs, filter (\x -> x `isSubsetOf` (usefuls ++ terminals)) rhs) --filters the rhs of the rule (whether the subrule only contains symbols that are either useful or terminal)
    filteredRules = filter (\r -> (fst r) `elem` usefuls) rules --filters the rules (whether their lhs is a useful symbol)
    usefuls = getUsefuls grammar
    (start, eps, nonterminals, terminals, rules) = grammar

--------------------------------------------------------------------------------LENGTH REDUCTION---------------------------------------------------------------------------------------

concatRule :: [Symbol] -> Symbol
concatRule [x] = x
concatRule (x:xs) = x ++ "," ++ concatRule xs

--falseNT ["a","A","b","B"] == "{a,A,b,B}" : flaseNT ["A","b","B"]
falseNT :: [Symbol] -> Symbol
falseNT xs = "{" ++ (concatRule xs) ++ "}"

--example call: sliceHelper "S" ["a","A","b","B"] /// this will start slicing the S -> "aAbB" rule
sliceHelper :: Symbol -> [Symbol] -> [Rule]
sliceHelper lhs rhs@(x:xs)
    | length rhs > 2 = (lhs, [[x, flsNT]]) : sliceHelper flsNT xs
    | otherwise = [(lhs, [rhs])]
    where
    flsNT = falseNT xs
    
--slices a rule that has exactly ONE subrule
subSlice :: Rule -> [Rule]
subSlice rule@(lhs, [rhs]) = sliceHelper lhs rhs


--slices a rule with ANY number of subrules
sliceRule :: Rule -> [Rule]
sliceRule rule@(lhs, rhs) = (initRule : newRuleSet) --this will slice each rule even if they have the same ending /// we have to get rid of duplicates (we will do so in sliceRules)
    where
    initRules = [ head $ subSlice (lhs, [singleSubRule]) | singleSubRule <- rhs ]  --the subSliced rules that have the same lhs of the rule being sliced (the param of this function)
    initRule = (lhs, concatMap (snd) initRules) --this rule will have multiple subrules, including the ones that we got from slicing (but all have the SAME lhs)
    newRuleSet = concat [ tail $ subSlice (lhs, [singleSubRule]) | singleSubRule <- rhs ]

sliceRules :: [Rule] -> [Rule]
sliceRules rules = nubBy (\x y -> fst x == fst y) $ concat [ sliceRule r | r <- rules ] --getting rid of duplicates

reduceLength :: Grammar -> Grammar
reduceLength grammar = (start, eps, newNonTerminals, terminals, newRules)
    where
    newNonTerminals = map fst newRules
    newRules = sliceRules rules
    (start, eps, nonterminals, terminals, rules) = grammar
    
    
--------------------------------------------------------------------------------EPSILON---------------------------------------------------------------------------------------

--TODO: generalize
broadenSet :: Grammar -> [Symbol] -> [Symbol]
broadenSet grammar currentSet
    | currentSet == newSet = currentSet --this may produce errors in a case where the two lists contain the same items, but in different order (can be solved by mutual containment) /// it probably won't since the map function will always preserve the order of the left-hand sides
    | otherwise = broadenSet grammar newSet
    where
    newSet = map fst (filter (\(lhs,rhs) -> any (\x -> x `isSubsetOf` (eps : currentSet)) rhs) rules) --gets the lhs of each rule that has at least one rhs (a subrule) that is a subset of the currentSet and the epsilon
    (start, eps, nonterminals, terminals, rules) = grammar

transformHelper :: [Symbol] -> WorD -> [WorD]
transformHelper set subRhs@[a] = [[a]]
transformHelper set subRhs@[a,b]
        | a `elem` set && b `elem` set = subRhs:[[a], [b]]
        | a `elem` set = subRhs:[[b]]
        | b `elem` set = subRhs:[[a]]
        | otherwise = [[a,b]]
    
transformRule :: [Symbol] -> Rule -> Rule
transformRule set rule@(lhs,rhs) = (lhs, nub $ concatMap (transformHelper set) rhs)

    
removeEpsilonRules :: Grammar -> Grammar
removeEpsilonRules grammar = (start, eps, nonterminals, terminals \\ [eps], newRules)
    where
    newRules = map (transformRule set) rules
    set = broadenSet grammar []
    (start, eps, nonterminals, terminals, rules) = grammar
    

--------------------------------------------------------------------------------DECHAINING---------------------------------------------------------------------------------------

isSingleton :: [a] -> Bool
isSingleton [x] = True
isSingleton _ = False;

--broadenChainSet grammar [] ["S"] will get all the nonterminals that you can reach from S on chain
broadenChainSet :: Grammar -> [Symbol] -> [Symbol] -> [Symbol]
broadenChainSet _ checkedSet [] = checkedSet
broadenChainSet grammar checkedSet currentSet@(x:xs) = broadenChainSet grammar (x:checkedSet) (xs ++ newNts)
   where 
   chainNts = concat $ filter (\y -> isSingleton y) rhs
   currentRule@(lhs, rhs) = finD (\(a,b) -> a == x) rules
   newNts = [ nt | nt <- chainNts, not (nt `elem` currentSet) && not (nt `elem` checkedSet) && nt `elem` nonterminals]
   (start, eps, nonterminals, terminals, rules) = grammar


dechain :: Grammar -> Grammar
dechain grammar = (start, eps, nonterminals, terminals, newRules)
    where
    newRules = [copyChains rule | rule <- rules]
    copyChains r@(lhs, rhs) = (lhs, nub . removeSingles $ rhs ++ (concat [ snd $ chainRule s | s <- chainSet lhs])) --it gets all the NTs that can be reached on chain from the lhs of r, then it searches the corresponding rules, gets the rhs of those, then adds them to the rhs of r and finally removes all subRules that have a singleton && nonterminal rhs
    removeSingles l = filter (\y -> not (isSingleton y) || y `isSubsetOf` terminals) l --removes all elements that are one-length nonterminal lists
    chainRule s = finD (\(a,b) -> a == s) rules --gets the rule correspondng to the symbol s
    chainSet sym = broadenChainSet grammar [] [sym]
    (start, eps, nonterminals, terminals, rules) = grammar
    
    
--------------------------------------------------------------------------------UNIT RULES---------------------------------------------------------------------------------------

--replaceTerminals terminals rhs
replaceTerminals :: [Symbol] -> [Symbol] -> [Symbol]
replaceTerminals terminals rhs
    | length rhs > 1 = [ falseNT_if sym  | sym <- rhs]
    | otherwise = rhs
    where 
    falseNT_if s
        | s `elem` terminals = falseNT [s]
        | otherwise = s

--replaceRule terminals rule
replaceRule :: [Symbol] -> Rule -> Rule
replaceRule terminals rule@(lhs,rhs) = (lhs, newRhs)
    where
    newRhs = [ replaceTerminals terminals r | r <- rhs ] 

eliminateUnitRules :: Grammar -> Grammar
eliminateUnitRules grammar = (start, eps, newNonTerminals, terminals, newRules)
    where
    newRules = [replaceRule terminals rule | rule <- rules] ++ [ (falseNT [t], [[t]]) | t <- terminals ]
    newNonTerminals = nonterminals ++ [ falseNT [t] | t <- terminals ]
    (start, eps, nonterminals, terminals, rules) = grammar


-------------------------------------------------------------------------------CHOMSKY NORMAL FORM-------------------------------------------------------------------------------------

chomsky :: Grammar -> Grammar
chomsky grammar = eliminateUnitRules $ dechain $ removeEpsilonRules $ reduceLength $ reduceGrammar grammar

checkRule :: [Symbol] -> [Symbol] -> Rule -> Bool
checkRule nonterminals terminals rule@(lhs,rhs)
    | all (\sr -> checkSubRule sr) rhs = True
    | otherwise = False
    where
    checkSubRule subrule
        | length subrule == 2 && all (\x -> x `elem` nonterminals) subrule = True
        | length subrule == 1 && all (\x -> x `elem` terminals) subrule = True
        | otherwise = False

isChomsky :: Grammar -> Bool
isChomsky grammar = noEps && rulesOK
    where
    rulesOK = all (\r -> checkRule nonterminals terminals r) rules
    noEps = not (eps `elem` terminals)
    (start, eps, nonterminals, terminals, rules) = grammar
    
    
 -------------------------------------------------------------------------------CYK  ALGORYTHM-------------------------------------------------------------------------------------

--for testing
toWord :: [Char] -> WorD
toWord [] = []
toWord (x:xs) = [x] : toWord xs
 
breakdown :: Rule -> [Rule']
breakdown rule@(lhs,rhs) = [ (lhs, subrule) | subrule <- rhs ]

breakdownRules :: Grammar -> [Rule']
breakdownRules grammar = concatMap (breakdown) rules
    where
    (_, _, _, _, rules) = grammar


--the the input lists should be sorted
merge :: (a -> a -> Bool) -> [a] -> [a] -> [a]
merge _ [] list2 = list2
merge _ list1 [] = list1
merge rel list1@(x:xs) list2@(y:ys)
    | rel x y   = x : merge rel xs list2
    | otherwise = y : merge rel list1 ys
    
mergesort :: (a -> a -> Bool) -> [a] -> [a]
mergesort _ [x] = [x]
mergesort rel xs = merge rel (mergesort rel firstHalf) (mergesort rel secondHalf)
    where
    half = length xs `div` 2
    firstHalf = take half xs
    secondHalf = drop half xs


descartes :: [[a]] -> [[a]]
descartes [] = [[]]
descartes (x:xs) = [  a : dx | a <- x, dx <- descartes xs]


sliceWord :: [a] -> [([a], [a])]
sliceWord word@(x:xs) = slcwrdHelper [x] xs
    where
    slcwrdHelper :: [a] -> [a] -> [([a], [a])]
    slcwrdHelper xs [y] = [(xs, [y])]
    slcwrdHelper xs other@(y:ys) = (xs, other) : slcwrdHelper (xs ++ [y]) ys
    --slcwrdHelper [x] ys = [([x], ys)]
    --slcwrdHelper xs ys = (xs, ys) : slcwrdHelper (init xs) (last xs : ys)
    
--searchForWord a b == c // a -> rhs to search for; b -> rules to filter (sorted by rhs); c -> lhs-s of each rule that has passed the query
searchForWord :: WorD -> [Rule'] -> [Symbol]
searchForWord _ [] = []
searchForWord word rules@(r:rs)
    | word < rhs = []
    | word > rhs = searchForWord word rs
    | otherwise = lhs : searchForWord word rs
    where (lhs, rhs) = r

sortedbrules1 = mergesort (\(_,a) (_,b) -> a < b) $ breakdownRules $ chomsky grammar1
sortedbrules2 = mergesort (\(_,a) (_,b) -> a < b) $ breakdownRules $ chomsky grammar2
sortedbrules3 = mergesort (\(_,a) (_,b) -> a < b) $ breakdownRules $ chomsky grammar3
    

cyk :: [Rule'] -> WorD -> [Symbol]
cyk rules [t] = searchForWord [t] rules
cyk rules word = concatMap (flip (searchForWord) rules) descartesWords
    where
    descartesWords = concat [ descartes [cyk rules pre, cyk rules suf] | w@(pre,suf) <- sliceWord word]
    
    --searchForWord ["a"] ( mergesort (\(_,a) (_,b) -> a < b) (breakdownRules (chomsky grammar1)))
    
isInLanguage :: WorD -> Grammar -> Bool
isInLanguage word grammar = start `elem` (cyk rules' word)
    where
    rules' = mergesort (\(_,a) (_,b) -> a < b) $ breakdownRules $ cgrammar
    (start, eps, nonterminals, terminals, rules) = cgrammar
    cgrammar = chomsky grammar

    
 -------------------------------------------------------------------------------EXAMPLE INPUTS-------------------------------------------------------------------------------------
   
    
    
terminals1 = ["a","b","epsilon"] :: [Symbol]
nonterminals1 = ["S","A","B","C","D"] :: [Symbol]
rules1 = [("S", [["A"], ["B"],       ["A","B","B","B"], ["C"]])
         ,("A", [["a"], ["a","B"],   ["a","A","b","B"]])
         ,("B", [["b"], ["epsilon"], ["A","b","B"]])
         ,("C", [["a"], ["a","b"],   ["A"],["D"]])
         ,("D", [["D"], ["D","D"]])] :: [Rule]
grammar1 = ("S", "epsilon", nonterminals1, terminals1, rules1) :: Grammar


terminals2 = ["a","b","c","d","epsilon"] :: [Symbol]
nonterminals2 = ["S","A","B","C","D"] :: [Symbol]
rules2 = [("S", [["A"], ["B"],       ["A","B","B","B"], ["C"]])
         ,("A", [["a"], ["a","B"],   ["a","A","b","B"]])
         ,("B", [["c"], ["A","C"],   ["D","C"]])
         ,("C", [["a"], ["a","b"],   ["A"],["D"]])
         ,("D", [["D"], ["D","D"],   ["d"]])] :: [Rule]
grammar2 = ("S", "epsilon", nonterminals2, terminals2, rules2) :: Grammar

terminals3 = ["a","b","epsilon"] :: [Symbol]
nonterminals3 = ["S"] :: [Symbol]
rules3 = [("S", [["a","S","b"], ["b","S","a"], ["S","S"], ["epsilon"] ])] :: [Rule]
grammar3 = ("S", "epsilon", nonterminals3, terminals3, rules3) :: Grammar

--isInLanguage (toWord "aababbabab") grammar3












