// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// NFT発行のコントラクト ERC721.sol をインポートします。
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

//OpenZeppelinが提供するヘルパー機能をインポートします。
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "hardhat/console.sol";
import "./libraries/Base64.sol";

// MyEpicGameコントラクトは、NFTの標準規格であるERC721を継承します。
contract MyEpicGame is ERC721 {
    struct CharacterAttributes {
        uint256 characterIndex;
        string name;
        string imageURI;
        uint256 hp;
        uint256 maxHp;
        uint256 attackDamage;
    }
    struct BigBoss {
        string name;
        string imageURI;
        uint256 hp;
        uint256 maxHp;
        uint256 attackDamage;
    }
    BigBoss public bigBoss;

    //OpenZeppelin が提供する tokenIds を簡単に追跡するライブラリを呼び出しています。
    using Counters for Counters.Counter;
    // tokenIdはNFTの一意な識別子で、0, 1, 2, .. N のように付与されます。
    Counters.Counter private _tokenIds;

    // キャラクターのデフォルトデータを保持するための配列 defaultCharacters を作成します。それぞれの配列は、CharacterAttributes 型です。
    CharacterAttributes[] defaultCharacters;

    // NFTの tokenId と CharacterAttributes を紐づける mapping を作成します。
    mapping(uint256 => CharacterAttributes) public nftHolderAttributes;

    // ユーザーのアドレスと NFT の tokenId を紐づける mapping を作成しています。
    mapping(address => uint256) public nftHolders;

    // ユーザーが NFT を Mint したこと示すイベント
    event CharacterNFTMinted(
        address sender,
        uint256 tokenId,
        uint256 characterIndex
    );
    // ボスへの攻撃が完了したことを示すイベント
    event AttackComplete(uint256 newBossHp, uint256 newPlayerHp);

    constructor(
        string[] memory characterNames,
        string[] memory characterImageURIs,
        uint256[] memory characterHp,
        uint256[] memory characterAttackDmg,
        string memory bossName,
        string memory bossImageURI,
        uint256 bossHp,
        uint256 bossAttackDamage
    )
        // 作成するNFTの名前とそのシンボルをERC721規格に渡しています。
        ERC721("Jyomons", "JYOMON")
    {
        // ボスを初期化します。ボスの情報をグローバル状態変数 "bigBoss"に保存します。
        bigBoss = BigBoss({
            name: bossName,
            imageURI: bossImageURI,
            hp: bossHp,
            maxHp: bossHp,
            attackDamage: bossAttackDamage
        });
        console.log(
            "Done initializing boss %s w/ HP %s, img %s",
            bigBoss.name,
            bigBoss.hp,
            bigBoss.imageURI
        );
        // ゲームで扱う全てのキャラクターをループ処理で呼び出し、それぞれのキャラクターに付与されるデフォルト値をコントラクトに保存します。
        // 後でNFTを作成する際に使用します。
        for (uint256 i = 0; i < characterNames.length; i += 1) {
            defaultCharacters.push(
                CharacterAttributes({
                    characterIndex: i,
                    name: characterNames[i],
                    imageURI: characterImageURIs[i],
                    hp: characterHp[i],
                    maxHp: characterHp[i],
                    attackDamage: characterAttackDmg[i]
                })
            );

            CharacterAttributes memory character = defaultCharacters[i];

            //  ハードハットのconsole.log()では、任意の順番で最大4つのパラメータを指定できます。
            // 使用できるパラメータの種類: uint, string, bool, address
            console.log(
                "Done initializing %s w/ HP %s, img %s",
                character.name,
                character.hp,
                character.imageURI
            );
        }

        // 次の NFT が Mint されるときのカウンターをインクリメントします。
        _tokenIds.increment();
    }

    // ユーザーは mintCharacterNFT 関数を呼び出して、NFT を Mint ことができます。
    // _characterIndex は フロントエンドから送信されます。
    function mintCharacterNFT(uint256 _characterIndex) external {
        // 現在の tokenId を取得します（constructor内でインクリメントしているため、1から始まります）。
        uint256 newItemId = _tokenIds.current();

        // msg.sender でフロントエンドからユーザーのアドレスを取得して、NFT をユーザーに Mint します。
        _safeMint(msg.sender, newItemId);

        // mapping で定義した tokenId を CharacterAttributesに紐付けます。
        nftHolderAttributes[newItemId] = CharacterAttributes({
            characterIndex: _characterIndex,
            name: defaultCharacters[_characterIndex].name,
            imageURI: defaultCharacters[_characterIndex].imageURI,
            hp: defaultCharacters[_characterIndex].hp,
            maxHp: defaultCharacters[_characterIndex].maxHp,
            attackDamage: defaultCharacters[_characterIndex].attackDamage
        });

        console.log(
            "Minted NFT w/ tokenId %s and characterIndex %s",
            newItemId,
            _characterIndex
        );

        // NFTの所有者を簡単に確認できるようにします。
        nftHolders[msg.sender] = newItemId;

        // 次に使用する人のためにtokenIdをインクリメントします。
        _tokenIds.increment();

        emit CharacterNFTMinted(msg.sender, newItemId, _characterIndex);
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        CharacterAttributes memory charAttributes = nftHolderAttributes[
            _tokenId
        ];
        // charAttributes のデータ編集して、JSON の構造に合わせた変数に格納しています。
        string memory strHp = Strings.toString(charAttributes.hp);
        string memory strMaxHp = Strings.toString(charAttributes.maxHp);
        string memory strAttackDamage = Strings.toString(
            charAttributes.attackDamage
        );

        string memory json = Base64.encode(
            // abi.encodePacked で文字列を結合します。
            // OpenSeaが採用するJSONデータをフォーマットしています。
            abi.encodePacked(
                '{"name": "',
                charAttributes.name,
                " -- NFT #: ",
                Strings.toString(_tokenId),
                '", "description": "This is an NFT that lets people play in the game Metaverse Slayer!", "image": "',
                charAttributes.imageURI,
                '", "attributes": [ { "trait_type": "Health Points", "value": ',
                strHp,
                ', "max_value":',
                strMaxHp,
                '}, { "trait_type": "Attack Damage", "value": ',
                strAttackDamage,
                "} ]}"
            )
        );
        // 文字列 data:application/json;base64, と json の中身を結合して、tokenURI を作成しています。
        string memory output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );
        return output;
    }

    function attackBoss() public {
        // 1. プレイヤーのNFTの状態を取得します。
        uint256 nftTokenIdOfPlayer = nftHolders[msg.sender];
        CharacterAttributes storage player = nftHolderAttributes[
            nftTokenIdOfPlayer
        ];
        console.log(
            "\nPlayer w/ character %s about to attack. Has %s HP and %s AD",
            player.name,
            player.hp,
            player.attackDamage
        );
        console.log(
            "Boss %s has %s HP and %s AD",
            bigBoss.name,
            bigBoss.hp,
            bigBoss.attackDamage
        );

        // 2. プレイヤーのHPが0以上であることを確認する。
        require(player.hp > 0, "Error: character must have HP to attack boss.");
        // 3. ボスのHPが0以上であることを確認する。
        require(bigBoss.hp > 0, "Error: boss must have HP to attack boss.");

        // 4. プレイヤーがボスを攻撃できるようにする。
        if (bigBoss.hp < player.attackDamage) {
            bigBoss.hp = 0;
        } else {
            bigBoss.hp = bigBoss.hp - player.attackDamage;
        }
        // 5. ボスがプレイヤーを攻撃できるようにする。
        if (player.hp < bigBoss.attackDamage) {
            player.hp = 0;
        } else {
            player.hp = player.hp - bigBoss.attackDamage;
        }

        // プレイヤーの攻撃をターミナルに出力する。
        console.log("Player attacked boss. New boss hp: %s", bigBoss.hp);
        // ボスの攻撃をターミナルに出力する。
        console.log("Boss attacked player. New player hp: %s\n", player.hp);

        emit AttackComplete(bigBoss.hp, player.hp);
    }

    function checkIfUserHasNFT()
        public
        view
        returns (CharacterAttributes memory)
    {
        // ユーザーの tokenId を取得します。
        uint256 userNftTokenId = nftHolders[msg.sender];

        // ユーザーがすでにtokenIdを持っている場合、そのキャラクターの属性情報を返します。
        if (userNftTokenId > 0) {
            return nftHolderAttributes[userNftTokenId];
        }
        // それ以外の場合は、空文字を返します。
        else {
            CharacterAttributes memory emptyStruct;
            return emptyStruct;
        }
    }

    function getAllDefaultCharacters()
        public
        view
        returns (CharacterAttributes[] memory)
    {
        return defaultCharacters;
    }

    function getBigBoss() public view returns (BigBoss memory) {
        return bigBoss;
    }
}
